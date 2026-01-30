import Foundation
import Combine

/// Base class for ViewModels providing common state management and error handling.
///
/// This class provides:
/// - Standard `isLoading` and `error` published properties
/// - A common `performOperation` method for async operations with automatic error handling
/// - Consistent error handling pattern across all ViewModels
///
/// Usage:
/// ```swift
/// class MyViewModel: BaseViewModel {
///     func doSomething() async {
///         await performOperation {
///             try await self.gitService.someOperation()
///         }
///     }
/// }
/// ```
@MainActor
class BaseViewModel: ObservableObject {
    /// Indicates whether an operation is currently in progress.
    @Published private(set) var isLoading: Bool = false

    /// Indicates whether a specific operation (like checkout, merge) is in progress.
    /// Use this for operations that should block UI but not show loading state.
    @Published private(set) var isOperationInProgress: Bool = false

    /// The current error state, if any.
    @Published var error: GitError?

    /// Performs an async operation with automatic loading state and error handling.
    ///
    /// - Parameters:
    ///   - showLoading: Whether to set `isLoading` to true during the operation. Default is true.
    ///   - operation: The async throwing operation to perform.
    /// - Returns: Whether the operation succeeded.
    @discardableResult
    func performOperation(showLoading: Bool = true, _ operation: () async throws -> Void) async -> Bool {
        if showLoading {
            isLoading = true
        }
        isOperationInProgress = true
        defer {
            if showLoading {
                isLoading = false
            }
            isOperationInProgress = false
        }

        do {
            try await operation()
            error = nil
            return true
        } catch let gitError as GitError {
            error = gitError
            return false
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            return false
        }
    }

    /// Performs an async operation that returns a value, with automatic loading state and error handling.
    ///
    /// - Parameters:
    ///   - showLoading: Whether to set `isLoading` to true during the operation. Default is true.
    ///   - operation: The async throwing operation to perform.
    /// - Returns: The result of the operation, or nil if it failed.
    func performOperationWithResult<T>(showLoading: Bool = true, _ operation: () async throws -> T) async -> T? {
        if showLoading {
            isLoading = true
        }
        isOperationInProgress = true
        defer {
            if showLoading {
                isLoading = false
            }
            isOperationInProgress = false
        }

        do {
            let result = try await operation()
            error = nil
            return result
        } catch let gitError as GitError {
            error = gitError
            return nil
        } catch {
            self.error = .unknown(message: error.localizedDescription)
            return nil
        }
    }

    /// Clears the current error state.
    func clearError() {
        error = nil
    }
}
