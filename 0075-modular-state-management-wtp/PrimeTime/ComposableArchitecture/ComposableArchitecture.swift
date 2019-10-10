import Combine
import SwiftUI
import Overture

public final class Store<Value, Action>: ObservableObject {
  private let reducer: (inout Value, Action) -> Void
  @Published public private(set) var value: Value
  private var cancellable: Cancellable?

  public init(initialValue: Value, reducer: @escaping (inout Value, Action) -> Void) {
    self.reducer = reducer
    self.value = initialValue
  }

  public func send(_ action: Action) {
    self.reducer(&self.value, action)
  }
  
  public func view<LocalValue, LocalAction>(
    value toLocalValue: @escaping (Value) -> LocalValue,
    action toGlobalAction: @escaping (LocalAction) -> Action
  ) -> Substore<LocalValue, LocalAction> {
    .init(
      getGlobalValue: { self.value },
      sendGlobalAction: send,
      globalObjectWillChange: objectWillChange,
      value: toLocalValue,
      action: toGlobalAction
    )
  }
}

public final class Substore<LocalValue, LocalAction>: ObservableObject {    
  let _value: () -> LocalValue
  public var value: LocalValue { _value() }
  public let send: (LocalAction) -> Void
    
  public let objectWillChange = PassthroughSubject<Void, Never>()
  var cancellable: AnyCancellable? = nil
    
  init<Value, Action, P>(
    getGlobalValue: @escaping () -> Value,
    sendGlobalAction: @escaping (Action) -> Void,
    globalObjectWillChange: P,
    value toLocalValue: @escaping (Value) -> LocalValue,
    action toGlobalAction: @escaping (LocalAction) -> Action
  ) where P: Publisher, P.Output == Void, P.Failure == Never {
    self._value = { toLocalValue(getGlobalValue()) }
    self.send = { localAction in sendGlobalAction(toGlobalAction(localAction)) }
    self.cancellable = globalObjectWillChange.subscribe(objectWillChange)
  }
    
  public func view<HyperLocalValue, HyperLocalAction>(
    value toHyperLocalValue: @escaping (LocalValue) -> HyperLocalValue,
    action toLocalAction: @escaping (HyperLocalAction) -> LocalAction
  ) -> Substore<HyperLocalValue, HyperLocalAction> {
    .init(
      getGlobalValue: _value,
      sendGlobalAction: send,
      globalObjectWillChange: objectWillChange,
      value: toHyperLocalValue,
      action: toLocalAction
    )
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

