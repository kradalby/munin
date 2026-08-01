//
//  main.swift
//  VIPSGenerator
//
//  Swift-based VIPS operation wrapper generator
//

import VIPSIntrospection
import Foundation
import Subprocess

// MARK: - Command Line Arguments

struct Arguments {
    var outputDir: String = "Sources/VIPS/Generated"
    var dryRun: Bool = false
    var verbose: Bool = false
    var operation: String? = nil
    var listOutputs: Bool = false
}

func parseArguments() -> Arguments {
    var args = Arguments()
    let commandLineArgs = CommandLine.arguments
    var i = 1

    while i < commandLineArgs.count {
        let arg = commandLineArgs[i]

        switch arg {
        case "--output-dir", "-o":
            i += 1
            if i < commandLineArgs.count {
                args.outputDir = commandLineArgs[i]
            }
        case "--dry-run":
            args.dryRun = true
        case "--verbose":
            args.verbose = true
        case "--operation":
            i += 1
            if i < commandLineArgs.count {
                args.operation = commandLineArgs[i]
            }
        case "--list-outputs":
            args.listOutputs = true
        case "--help", "-h":
            printHelp()
            exit(0)
        default:
            if arg.hasPrefix("-") {
                print("Unknown option: \(arg)")
                printHelp()
                exit(1)
            }
        }

        i += 1
    }

    return args
}

func printHelp() {
    print("""
    VIPS Swift Code Generator

    Usage: vips-generator [options]

    Options:
        --output-dir, -o <path>    Output directory (default: Sources/VIPS/Generated)
        --dry-run                  Print what would be generated without writing
        --verbose                  Print progress information
        --operation <name>         Generate single operation (for testing)
        --list-outputs             List output file paths (one per line) and exit
        --help, -h                 Show this help message
    """)
}

// MARK: - Formatting

/// Format generated Swift files using swift format
func formatGeneratedFiles(outputDirectory: String, verbose: Bool) async {
    do {
        // Run swift format on all files in the output directory
        // Collect stderr in case of errors
        let result = try await run(
            .name("swift"),
            arguments: [
                "format",
                "--in-place",
                "--recursive",
                "--parallel",
                outputDirectory
            ],
            output: .discarded,
            error: .string(limit: 16384)
        )

        if result.terminationStatus.isSuccess {
            if verbose {
                print("  ✅ Formatted all generated files")
            }
        } else {
            print("  ⚠️  swift format exited with status \(result.terminationStatus)")
            if let stderr = result.standardError, !stderr.isEmpty {
                print("  Error output:")
                for line in stderr.split(separator: "\n") {
                    print("    \(line)")
                }
            }
        }
    } catch {
        // swift format might not be available in older toolchains
        if verbose {
            print("  ⚠️  Failed to run swift format: \(error)")
            print("  ℹ️  Formatting requires Swift 6.0 or later")
        }
    }
}

// MARK: - Main Function

func main() async {
    let args = parseArguments()

    do {
        if args.verbose {
            print("Initializing VIPS library...")
        }
        try VIPSIntrospection.initialize()
        defer { VIPSIntrospection.shutdown() }

        if args.verbose {
            print("Discovering VIPS operations...")
        }
        var operations = try VIPSIntrospection.getAllOperations()

        // Note: Don't add "crop" as synonym - it would duplicate "extract_area"
        // The Python generator adds it but handles deduplication differently

        if !args.listOutputs {
            print("Found \(operations.count) operations")
        }

        // Filter to single operation if requested
        if let singleOp = args.operation {
            operations = operations.filter { $0 == singleOp }
            if operations.isEmpty {
                print("Error: Operation '\(singleOp)' not found")
                exit(1)
            }
            print("Generating single operation: \(singleOp)")
        }

        let generator = CodeGenerator()
        let overloads = OverloadGenerators()
        var categorizedMethods: [String: [(nickname: String, code: String)]] = [:]

        // Operations to exclude (matching Python generator)
        let excludedOperations = Set([
            "avifsave_target",
            "magicksave_bmp",
            "magicksave_bmp_buffer",
            "pbmsave_target",
            "pfmsave_target",
            "pgmsave_target",
            "pnmsave_target",
            "linear",      // Has manual implementation with multiple overloads
            "project",     // Has manual implementation with tuple return type
            "profile"      // Has manual implementation with tuple return type
        ])

        // Const variant mapping
        let constVariants = ["remainder": "remainder_const"]

        if args.verbose && !args.listOutputs {
            print("Generating wrappers...")
        }

        for nickname in operations {
            // Skip excluded operations
            if excludedOperations.contains(nickname) {
                continue
            }

            // Get operation details - skip abstract types that fail introspection
            let details: VIPSOperationDetails
            do {
                details = try VIPSIntrospection.getOperationDetails(nickname)
            } catch {
                // Can fail for abstract types, skip them
                if args.verbose && !args.listOutputs {
                    print("  Skipping \(nickname) (abstract type)")
                }
                continue
            }

            // Generate main wrapper
            if let wrapper = generator.generateWrapper(for: details) {
                let category = getOperationCategory(nickname)

                // Apply version guards if needed
                var code = wrapper
                if let versionGuard = getOperationVersionGuard(nickname) {
                    code = "\(versionGuard)\n\(code)\n#endif"
                }

                categorizedMethods[category, default: []].append((nickname, code))

                if args.verbose && !args.listOutputs {
                    print("  Generated \(nickname) -> \(category)")
                }
            }

            // Generate UnsafeRawBufferPointer overload if this operation has blob parameters
            if let unsafeBufferOverload = overloads.generateUnsafeBufferOverload(for: details) {
                let category = getOperationCategory(nickname)
                var code = unsafeBufferOverload
                if let versionGuard = getOperationVersionGuard(nickname) {
                    code = "\(versionGuard)\n\(code)\n#endif"
                }
                categorizedMethods[category, default: []].append((
                    nickname: "\(nickname)_unsafe_buffer_overload",
                    code: code
                ))
            }

            // Generate const overloads if this operation has them
            if let constOpName = constVariants[nickname] {
                let constDetails = try VIPSIntrospection.getOperationDetails(constOpName)
                let constOverloads = overloads.generateSimpleConstOverloads(
                    baseOp: nickname,
                    constOp: constDetails
                )

                let category = getOperationCategory(nickname)
                for (i, overloadCode) in constOverloads.enumerated() {
                    var code = overloadCode
                    if let versionGuard = getOperationVersionGuard(nickname) {
                        code = "\(versionGuard)\n\(code)\n#endif"
                    }
                    categorizedMethods[category, default: []].append((
                        nickname: "\(nickname)_overload_\(i)",
                        code: code
                    ))
                }
            }
        }

        if args.dryRun {
            print("\nOperations by category:")
            for category in categorizedMethods.keys.sorted() {
                let methods = categorizedMethods[category]!
                print("  \(category): \(methods.count) operations")
                for (nickname, _) in methods.prefix(3) {
                    print("    - \(nickname)")
                }
                if methods.count > 3 {
                    print("    ... and \(methods.count - 3) more")
                }
            }
            return
        }

        // If --list-outputs, just print the file paths and exit
        if args.listOutputs {
            let writer = FileWriter(outputDirectory: args.outputDir)
            for category in categorizedMethods.keys.sorted() {
                let (filepath, _) = writer.getFilePath(for: category)
                print(filepath.path())
            }
            return
        }

        // Write files
        if args.verbose {
            print("\nWriting files to \(args.outputDir)...")
        }

        let writer = FileWriter(outputDirectory: args.outputDir)
        for category in categorizedMethods.keys.sorted() {
            let methods = categorizedMethods[category]!
            try writer.writeCategory(category, methods: methods)
            print("  ✅ Generated \(category.lowercased().replacingOccurrences(of: "/", with: "_")).generated.swift (\(methods.count) operations)")
        }

        print("\nGeneration complete!")

        // Format generated files with swift format
        if args.verbose {
            print("\nFormatting generated files...")
        }
        await formatGeneratedFiles(outputDirectory: args.outputDir, verbose: args.verbose)

        print("\nSummary:")
        let totalOperations = categorizedMethods.values.reduce(0) { $0 + $1.count }
        print("  Total operations: \(totalOperations)")
        print("  Total categories: \(categorizedMethods.count)")

    } catch {
        print("Error: \(error)")
        exit(1)
    }
}

await main()
