import Foundation
import XCTest
@testable import catalogue_management

@MainActor
final class ViewModelTests: XCTestCase {
    func testHomeViewModelLoadsCategoriesAndFeaturedProducts() async {
        let repository = TestProductRepository(
            products: [sampleProduct],
            categories: [catalogue_management.Category(name: "electronics")]
        )
        let viewModel = HomeViewModel(repository: repository)

        await viewModel.load()

        guard case let .loaded(content) = viewModel.state else {
            XCTFail("Expected home content")
            return
        }
        XCTAssertEqual(content.featuredProducts, [sampleProduct])
        XCTAssertEqual(content.categories, [catalogue_management.Category(name: "electronics")])
    }

    func testHomeViewModelReportsEmptyAndFailureStates() async {
        let emptyViewModel = HomeViewModel(repository: TestProductRepository())
        await emptyViewModel.load()
        if case .empty = emptyViewModel.state {} else { XCTFail("Expected empty state") }

        let failedViewModel = HomeViewModel(repository: TestProductRepository(failure: .transport))
        await failedViewModel.load()
        if case .failed = failedViewModel.state {} else { XCTFail("Expected failure state") }
    }

    func testCategoryAndSearchViewModelsExposeLoadedAndEmptyStates() async {
        let categoryContent = CategoryProducts(category: sampleProduct.category, featured: [sampleProduct], remaining: [])
        let repository = TestProductRepository(products: [sampleProduct], categoryProducts: categoryContent)
        let categoryViewModel = CategoryViewModel(repository: repository)
        await categoryViewModel.load(category: sampleProduct.category)
        if case let .loaded(value) = categoryViewModel.state {
            XCTAssertEqual(value, categoryContent)
        } else {
            XCTFail("Expected loaded category")
        }

        let searchViewModel = SearchViewModel(repository: TestProductRepository())
        await searchViewModel.search(query: "   ")
        if case .empty = searchViewModel.state {} else { XCTFail("Expected empty search state") }
    }

    func testSearchAndProductDetailViewModelsLoadResults() async {
        let repository = TestProductRepository(products: [sampleProduct])
        let searchViewModel = SearchViewModel(repository: repository)
        await searchViewModel.search(query: "boots")
        if case let .loaded(products) = searchViewModel.state {
            XCTAssertEqual(products, [sampleProduct])
        } else {
            XCTFail("Expected loaded search results")
        }

        let detailViewModel = ProductDetailViewModel(repository: repository)
        await detailViewModel.load(productID: sampleProduct.id)
        if case let .loaded(product) = detailViewModel.state {
            XCTAssertEqual(product, sampleProduct)
        } else {
            XCTFail("Expected loaded product detail")
        }
    }

    func testSearchRequestsCompletingOutOfOrderKeepTheNewestResults() async {
        let repository = ControlledProductRepository()
        let viewModel = SearchViewModel(repository: repository)

        let olderRequest = Task { await viewModel.search(query: "older") }
        await repository.waitUntilStarted("search:older")
        let newerRequest = Task { await viewModel.search(query: "newer") }
        await repository.waitUntilStarted("search:newer")

        let newerProduct = product(id: "2", title: "Newer")
        await repository.resolveSearch("newer", with: [newerProduct])
        await newerRequest.value
        await repository.resolveSearch("older", with: [product(id: "1", title: "Older")])
        await olderRequest.value

        if case let .loaded(products) = viewModel.state {
            XCTAssertEqual(products, [newerProduct])
        } else {
            XCTFail("Expected the newest search results to remain loaded")
        }
    }

    func testClearingSearchInvalidatesAnInFlightRequest() async {
        let repository = ControlledProductRepository()
        let viewModel = SearchViewModel(repository: repository)
        let request = Task { await viewModel.search(query: "boots") }
        await repository.waitUntilStarted("search:boots")

        await viewModel.search(query: "   ")
        if case .empty = viewModel.state {} else { XCTFail("Expected an empty state after clearing search") }

        await repository.resolveSearch("boots", with: [sampleProduct])
        await request.value
        if case .empty = viewModel.state {} else { XCTFail("The cleared query must invalidate its pending response") }
    }

    func testCancellationDoesNotBecomeSearchFailure() async {
        let repository = ControlledProductRepository()
        let viewModel = SearchViewModel(repository: repository)

        let urlErrorRequest = Task { await viewModel.search(query: "url-cancel") }
        await repository.waitUntilStarted("search:url-cancel")
        await repository.cancelSearch("url-cancel", withURLError: true)
        await urlErrorRequest.value
        if case .idle = viewModel.state {} else { XCTFail("URLError.cancelled should return the view model to idle") }

        let taskCancelledRequest = Task { await viewModel.search(query: "task-cancel") }
        await repository.waitUntilStarted("search:task-cancel")
        taskCancelledRequest.cancel()
        await repository.resolveSearch("task-cancel", with: [sampleProduct])
        await taskCancelledRequest.value
        if case .idle = viewModel.state {} else { XCTFail("Task cancellation must not publish a failure or result") }

        let staleCancellation = Task { await viewModel.search(query: "stale-cancel") }
        await repository.waitUntilStarted("search:stale-cancel")
        let currentRequest = Task { await viewModel.search(query: "current") }
        await repository.waitUntilStarted("search:current")
        let currentProduct = product(id: "3", title: "Current")
        await repository.resolveSearch("current", with: [currentProduct])
        await currentRequest.value
        await repository.cancelSearch("stale-cancel", withURLError: false)
        await staleCancellation.value
        if case let .loaded(products) = viewModel.state {
            XCTAssertEqual(products, [currentProduct])
        } else {
            XCTFail("A canceled stale request must not clear newer results")
        }
    }

    func testHomeCategoryAndProductDetailIgnoreStaleResponses() async {
        let repository = ControlledProductRepository()

        let home = HomeViewModel(repository: repository)
        let oldHomeLoad = Task { await home.load() }
        await repository.waitUntilStarted("categories", occurrence: 1)
        await repository.waitUntilStarted("featured", occurrence: 1)
        let newHomeLoad = Task { await home.load() }
        await repository.waitUntilStarted("categories", occurrence: 2)
        await repository.waitUntilStarted("featured", occurrence: 2)
        let newProduct = product(id: "2", title: "New home")
        await repository.resolveCategories(occurrence: 1, with: [Category(name: "new")])
        await repository.resolveFeatured(occurrence: 1, with: [newProduct])
        await newHomeLoad.value
        await repository.resolveCategories(occurrence: 0, with: [Category(name: "old")])
        await repository.resolveFeatured(occurrence: 0, with: [product(id: "1", title: "Old home")])
        await oldHomeLoad.value
        if case let .loaded(content) = home.state {
            XCTAssertEqual(content.categories, [Category(name: "new")])
            XCTAssertEqual(content.featuredProducts, [newProduct])
        } else {
            XCTFail("Expected newest home response")
        }

        let category = Category(name: "electronics")
        let categoryViewModel = CategoryViewModel(repository: repository)
        let oldCategoryLoad = Task { await categoryViewModel.load(category: category) }
        await repository.waitUntilStarted("category:electronics", occurrence: 1)
        let newCategoryLoad = Task { await categoryViewModel.load(category: category) }
        await repository.waitUntilStarted("category:electronics", occurrence: 2)
        let newestCategory = CategoryProducts(category: category, featured: [newProduct], remaining: [])
        await repository.resolveCategory("electronics", occurrence: 1, with: newestCategory)
        await newCategoryLoad.value
        await repository.resolveCategory("electronics", occurrence: 0, with: CategoryProducts(category: category, featured: [sampleProduct], remaining: []))
        await oldCategoryLoad.value
        if case let .loaded(content) = categoryViewModel.state {
            XCTAssertEqual(content, newestCategory)
        } else {
            XCTFail("Expected newest category response")
        }

        let detail = ProductDetailViewModel(repository: repository)
        let oldDetailLoad = Task { await detail.load(productID: "1") }
        await repository.waitUntilStarted("product:1")
        let newDetailLoad = Task { await detail.load(productID: "2") }
        await repository.waitUntilStarted("product:2")
        await repository.resolveProduct("2", with: newProduct)
        await newDetailLoad.value
        await repository.resolveProduct("1", with: sampleProduct)
        await oldDetailLoad.value
        if case let .loaded(content) = detail.state {
            XCTAssertEqual(content, newProduct)
        } else {
            XCTFail("Expected newest product detail response")
        }
    }

    func testEnquiryViewModelTransitionsToSuccessAndFailure() async {
        let request = EnquiryRequest(productId: 1, name: "John", email: "john@example.com", message: "Hello")
        let success = EnquiryViewModel(repository: TestEnquiryRepository(result: .success(EnquiryResponse(status: "sent"))))
        await success.submit(request)
        if case let .succeeded(response) = success.state {
            XCTAssertEqual(response.status, "sent")
        } else {
            XCTFail("Expected enquiry success")
        }

        let failure = EnquiryViewModel(repository: TestEnquiryRepository(result: .failure(.transport)))
        await failure.submit(request)
        if case .failed = failure.state {} else { XCTFail("Expected enquiry failure") }
    }

    func testEnquiryViewModelRejectsInvalidInputBeforeRepositorySubmission() async {
        let repository = TestEnquiryRepository(result: .success(EnquiryResponse(status: "sent")))
        let viewModel = EnquiryViewModel(repository: repository)
        let request = EnquiryRequest(productId: 1, name: " ", email: "invalid", message: " ")

        await viewModel.submit(request)

        if case let .failed(message) = viewModel.state {
            XCTAssertEqual(message, "Enter a name of up to 100 characters.")
        } else {
            XCTFail("Expected client-side validation failure")
        }
        let submissionCount = await repository.submissionCount()
        XCTAssertEqual(submissionCount, 0)
    }

    func testEnquiryViewModelRejectsDuplicateSubmissionsAndPreservesCancellation() async {
        let repository = ControlledEnquiryRepository()
        let viewModel = EnquiryViewModel(repository: repository)
        let request = EnquiryRequest(productId: 1, name: "John", email: "john@example.com", message: "Hello")

        let firstSubmission = Task { await viewModel.submit(request) }
        await repository.waitUntilSubmitted()
        await viewModel.submit(request)
        let countWhileSubmitting = await repository.submissionCount()
        XCTAssertEqual(countWhileSubmitting, 1)
        if case .submitting = viewModel.state {} else { XCTFail("Expected submission to remain in progress") }

        await repository.resolve(EnquiryResponse(status: "sent"))
        await firstSubmission.value
        if case .succeeded = viewModel.state {} else { XCTFail("Expected the accepted enquiry to succeed") }

        let cancelledRepository = ControlledEnquiryRepository()
        let cancelledViewModel = EnquiryViewModel(repository: cancelledRepository)
        let cancelledSubmission = Task { await cancelledViewModel.submit(request) }
        await cancelledRepository.waitUntilSubmitted()
        await cancelledRepository.cancel()
        await cancelledSubmission.value
        if case .idle = cancelledViewModel.state {} else { XCTFail("Cancellation should return the enquiry view model to idle") }
    }

    func testProductToEnquiryConversionFailureIsUserSafe() async {
        let repository = TestEnquiryRepository(result: .success(EnquiryResponse(status: "sent")))
        let viewModel = EnquiryViewModel(repository: repository)
        await viewModel.submit(
            product: product(id: "not-an-id", title: "Invalid"),
            name: "John",
            email: "john@example.com",
            message: "Hello"
        )

        if case let .failed(message) = viewModel.state {
            XCTAssertEqual(message, "This product cannot be used for an enquiry.")
        } else {
            XCTFail("Expected an ID conversion error")
        }
    }
}

private let sampleProduct = Product(
    id: "1",
    title: "Boots",
    description: "Leather boots",
    category: catalogue_management.Category(name: "electronics"),
    imageURL: URL(fileURLWithPath: "/boots.jpg"),
    price: Decimal(25.5),
    rating: ProductRating(rate: 4.5, count: 12)
)

private func product(id: String, title: String) -> Product {
    Product(
        id: id,
        title: title,
        description: "Description",
        category: Category(name: "electronics"),
        imageURL: URL(fileURLWithPath: "/\(id).jpg"),
        price: 1,
        rating: ProductRating(rate: 4, count: 1)
    )
}

private struct TestProductRepository: ProductRepository {
    let productValues: [Product]
    let categoryValues: [catalogue_management.Category]
    let categoryContent: CategoryProducts
    let failure: APIError?

    init(
        products: [Product] = [],
        categories: [catalogue_management.Category] = [],
        categoryProducts: CategoryProducts = CategoryProducts(category: catalogue_management.Category(name: "empty"), featured: [], remaining: []),
        failure: APIError? = nil
    ) {
        self.productValues = products
        self.categoryValues = categories
        self.categoryContent = categoryProducts
        self.failure = failure
    }

    func featuredProducts() async throws -> [Product] { try checkFailure(); return productValues }
    func categories() async throws -> [catalogue_management.Category] { try checkFailure(); return categoryValues }
    func products(in category: catalogue_management.Category) async throws -> CategoryProducts { try checkFailure(); return categoryContent }
    func searchProducts(query: String) async throws -> [Product] { try checkFailure(); return productValues }
    func product(id: String) async throws -> Product {
        try checkFailure()
        guard let product = productValues.first(where: { $0.id == id }) else {
            throw APIError.httpStatus(statusCode: 404, code: "PRODUCT_NOT_FOUND")
        }
        return product
    }

    private func checkFailure() throws {
        if let failure { throw failure }
    }
}

private actor TestEnquiryRepository: EnquiryRepository {
    let result: Result<EnquiryResponse, APIError>
    private var submissions = 0

    init(result: Result<EnquiryResponse, APIError>) {
        self.result = result
    }

    func submit(_ request: EnquiryRequest) async throws -> EnquiryResponse {
        submissions += 1
        return try result.get()
    }

    func submissionCount() -> Int { submissions }
}

private actor ControlledProductRepository: ProductRepository {
    private typealias ProductContinuation = CheckedContinuation<[Product], any Error>
    private typealias CategoryContinuation = CheckedContinuation<[catalogue_management.Category], any Error>
    private typealias CategoryProductsContinuation = CheckedContinuation<CategoryProducts, any Error>
    private typealias ProductDetailContinuation = CheckedContinuation<Product, any Error>

    private struct StartWaiter {
        let occurrence: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var featuredContinuations: [ProductContinuation] = []
    private var categoryListContinuations: [CategoryContinuation] = []
    private var categoryProductContinuations: [String: [CategoryProductsContinuation]] = [:]
    private var productContinuations: [String: [ProductDetailContinuation]] = [:]
    private var searchContinuations: [String: [ProductContinuation]] = [:]
    private var startCounts: [String: Int] = [:]
    private var startWaiters: [String: [StartWaiter]] = [:]

    func featuredProducts() async throws -> [Product] {
        try await withCheckedThrowingContinuation { continuation in
            featuredContinuations.append(continuation)
            markStarted("featured")
        }
    }

    func categories() async throws -> [catalogue_management.Category] {
        try await withCheckedThrowingContinuation { continuation in
            categoryListContinuations.append(continuation)
            markStarted("categories")
        }
    }

    func products(in category: catalogue_management.Category) async throws -> CategoryProducts {
        try await withCheckedThrowingContinuation { continuation in
            categoryProductContinuations[category.name, default: []].append(continuation)
            markStarted("category:\(category.name)")
        }
    }

    func searchProducts(query: String) async throws -> [Product] {
        try await withCheckedThrowingContinuation { continuation in
            searchContinuations[query, default: []].append(continuation)
            markStarted("search:\(query)")
        }
    }

    func product(id: String) async throws -> Product {
        try await withCheckedThrowingContinuation { continuation in
            productContinuations[id, default: []].append(continuation)
            markStarted("product:\(id)")
        }
    }

    func waitUntilStarted(_ key: String, occurrence: Int = 1) async {
        guard startCounts[key, default: 0] < occurrence else { return }
        await withCheckedContinuation { continuation in
            startWaiters[key, default: []].append(StartWaiter(occurrence: occurrence, continuation: continuation))
        }
    }

    func resolveFeatured(occurrence: Int, with products: [Product]) {
        take(&featuredContinuations, occurrence: occurrence)?.resume(returning: products)
    }

    func resolveCategories(occurrence: Int, with categories: [catalogue_management.Category]) {
        take(&categoryListContinuations, occurrence: occurrence)?.resume(returning: categories)
    }

    func resolveCategory(_ name: String, occurrence: Int, with products: CategoryProducts) {
        take(&categoryProductContinuations, key: name, occurrence: occurrence)?.resume(returning: products)
    }

    func resolveProduct(_ id: String, with product: Product) {
        take(&productContinuations, key: id, occurrence: 0)?.resume(returning: product)
    }

    func resolveSearch(_ query: String, with products: [Product]) {
        take(&searchContinuations, key: query, occurrence: 0)?.resume(returning: products)
    }

    func cancelSearch(_ query: String, withURLError: Bool) {
        guard let continuation = take(&searchContinuations, key: query, occurrence: 0) else { return }
        continuation.resume(throwing: withURLError ? URLError(.cancelled) : CancellationError())
    }

    private func markStarted(_ key: String) {
        let count = startCounts[key, default: 0] + 1
        startCounts[key] = count
        let currentWaiters = startWaiters[key, default: []]
        var pending: [StartWaiter] = []
        for waiter in currentWaiters {
            if waiter.occurrence <= count {
                waiter.continuation.resume()
            } else {
                pending.append(waiter)
            }
        }
        startWaiters[key] = pending.isEmpty ? nil : pending
    }

    private func take<Value>(
        _ values: inout [CheckedContinuation<Value, any Error>],
        occurrence: Int
    ) -> CheckedContinuation<Value, any Error>? {
        guard values.indices.contains(occurrence) else { return nil }
        return values.remove(at: occurrence)
    }

    private func take<Value>(
        _ valuesByKey: inout [String: [CheckedContinuation<Value, any Error>]],
        key: String,
        occurrence: Int
    ) -> CheckedContinuation<Value, any Error>? {
        guard var values = valuesByKey[key], values.indices.contains(occurrence) else { return nil }
        let continuation = values.remove(at: occurrence)
        valuesByKey[key] = values.isEmpty ? nil : values
        return continuation
    }
}

private actor ControlledEnquiryRepository: EnquiryRepository {
    private var continuation: CheckedContinuation<EnquiryResponse, any Error>?
    private var submittedWaiter: CheckedContinuation<Void, Never>?
    private var submitted = false
    private var submissions = 0

    func submit(_ request: EnquiryRequest) async throws -> EnquiryResponse {
        submissions += 1
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            submitted = true
            submittedWaiter?.resume()
            submittedWaiter = nil
        }
    }

    func waitUntilSubmitted() async {
        guard !submitted else { return }
        await withCheckedContinuation { submittedWaiter = $0 }
    }

    func submissionCount() -> Int { submissions }

    func resolve(_ response: EnquiryResponse) {
        continuation?.resume(returning: response)
        continuation = nil
    }

    func cancel() {
        continuation?.resume(throwing: URLError(.cancelled))
        continuation = nil
    }
}
