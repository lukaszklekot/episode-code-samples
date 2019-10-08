import Combine
import SwiftUI
import Overture

public final class Store<Value, Action>: ObservableObject {
  private let reducer: (inout Value, Action) -> Void
  @Published public private(set) var value: Value
  private var cancellable: Cancellable?

  public init(initialValue: Value, reducer: @escaping (inout Value, Action) -> Void) {
//    self.objectWillChange
//    self.$value.sink(receiveValue: <#T##((Value) -> Void)##((Value) -> Void)##(Value) -> Void#>)
    self.reducer = reducer
    self.value = initialValue
  }

  public func send(_ action: Action) {
    self.reducer(&self.value, action)
  }

  // ((Value) -> LocalValue) -> (Store<Value ,_>) -> Store<LocalValue, _>
  // ((A) -> B) -> (Store<A ,_>) -> Store<B, _>
  // map: ((A) -> B) -> (F<A>) -> F<B>

//  public func view<LocalValue, LocalAction>(
//    value toLocalValue: @escaping (Value) -> LocalValue,
//    action toGlobalAction: @escaping (LocalAction) -> Action
//  ) -> Store<LocalValue, LocalAction> {
//    let localStore = Store<LocalValue, LocalAction>(
//      initialValue: toLocalValue(self.value),
//      reducer: { localValue, localAction in
//        self.send(toGlobalAction(localAction))
//        localValue = toLocalValue(self.value)
//    }
//    )
//    localStore.cancellable = self.$value.sink { [weak localStore] newValue in
//      localStore?.value = toLocalValue(newValue)
//    }
//    return localStore
//  }
  
  public func view<LocalValue, LocalAction>(
    value toLocalValue: @escaping (Value) -> LocalValue,
    action toGlobalAction: @escaping (LocalAction) -> Action
  ) -> Store<Value, Action>.Substore<LocalValue, LocalAction> {
    .init(store: self, value: toLocalValue, action: toGlobalAction)
  }

  // ((LocalAction) -> Action) -> (Store<_, Action>) -> Store<_, LocalAction>
  // ((B) -> A) -> (Store<_, A>) -> Store<_, B>
  // pullback: ((B) -> A) -> (F<A>) -> F<B>
}

public extension Store {
  final class Substore<LocalValue, LocalAction>: ObservableObject {
    public let store: Store<Value, Action>
    let toLocalValue: (Value) -> LocalValue
    let toGlobalAction: (LocalAction) -> Action
    
    public let objectWillChange = PassthroughSubject<Void, Never>()
    var cancellable: AnyCancellable? = nil
    
    init(
      store: Store<Value, Action>,
      value toLocalValue: @escaping (Value) -> LocalValue,
      action toGlobalAction: @escaping (LocalAction) -> Action
    ) {
      self.store = store
      self.toLocalValue = toLocalValue
      self.toGlobalAction = toGlobalAction
      
      cancellable = store.objectWillChange.subscribe(objectWillChange)
    }
    
    public var value: LocalValue {
      toLocalValue(store.value)
    }
    
    public func send(_ action: LocalAction) {
      store.send(toGlobalAction(action))
    }
    
    public func view<HyperLocalValue, HyperLocalAction>(
      value toHyperLocalValue: @escaping (LocalValue) -> HyperLocalValue,
      action toLocalAction: @escaping (HyperLocalAction) -> LocalAction
    ) -> Store<Value, Action>.Substore<HyperLocalValue, HyperLocalAction> {
      .init(
        store: store,
        value: pipe(toLocalValue, toHyperLocalValue),
        action: pipe(toLocalAction, toGlobalAction)
      )
    }
  }
}

func transform<A, B, Action>(
  _ reducer: (A, Action) -> A,
  _ f: (A) -> B
) -> (B, Action) -> B {
  fatalError()
}


public func combine<Value, Action>(
  _ reducers: (inout Value, Action) -> Void...
) -> (inout Value, Action) -> Void {
  return { value, action in
    for reducer in reducers {
      reducer(&value, action)
    }
  }
}

public func pullback<LocalValue, GlobalValue, LocalAction, GlobalAction>(
  _ reducer: @escaping (inout LocalValue, LocalAction) -> Void,
  value: WritableKeyPath<GlobalValue, LocalValue>,
  action: WritableKeyPath<GlobalAction, LocalAction?>
) -> (inout GlobalValue, GlobalAction) -> Void {
  return { globalValue, globalAction in
    guard let localAction = globalAction[keyPath: action] else { return }
    reducer(&globalValue[keyPath: value], localAction)
  }
}

public func logging<Value, Action>(
  _ reducer: @escaping (inout Value, Action) -> Void
) -> (inout Value, Action) -> Void {
  return { value, action in
    reducer(&value, action)
    print("Action: \(action)")
    print("Value:")
    dump(value)
    print("---")
  }
}

