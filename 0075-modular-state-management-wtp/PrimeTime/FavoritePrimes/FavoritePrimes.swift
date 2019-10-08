import ComposableArchitecture
import SwiftUI

public enum FavoritePrimesAction {
  case deleteFavoritePrimes(IndexSet)
}

public func favoritePrimesReducer(state: inout [Int], action: FavoritePrimesAction) {
  switch action {
  case let .deleteFavoritePrimes(indexSet):
    for index in indexSet {
      state.remove(at: index)
    }
  }
}

public struct FavoritePrimesView<AppState, AppAction>: View {
  @ObservedObject var store: Store<AppState, AppAction>.Substore<[Int], FavoritePrimesAction>

  public init(store: Store<AppState, AppAction>.Substore<[Int], FavoritePrimesAction>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(self.store.value, id: \.self) { prime in
        Text("\(prime)")
      }
      .onDelete { indexSet in
        self.store.send(.deleteFavoritePrimes(indexSet))
//        self.store.send(.counter(.incrTapped))
      }
    }
    .navigationBarTitle("Favorite primes")
  }
}

