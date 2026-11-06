// swift-tools-version: 5.10
import PackageDescription

let package = Package(
	name: "TestForge",
	defaultLocalization: "en",
	platforms: [.macOS(.v14)],
	targets: [
		.executableTarget(
			name: "TestForge",
			path: "Sources/TestForge",
			resources: [.process("Resources")]
		),
		.testTarget(
			name: "TestForgeTests",
			dependencies: ["TestForge"],
			path: "Tests/TestForgeTests"
		)
	]
)
