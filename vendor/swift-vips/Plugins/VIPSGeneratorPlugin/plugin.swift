//
//  plugin.swift
//  VIPSGeneratorPlugin
//
//  Build tool plugin that generates Swift wrappers for libvips operations
//

import Foundation
import PackagePlugin

@main
struct VIPSGeneratorPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        // Only apply to the VIPS target
        guard target.name == "VIPS" else {
            return []
        }

        // Get the generator tool
        let generator = try context.tool(named: "vips-generator")

        // Output directory for generated files (using URL-based API)
        let outputDir = context.pluginWorkDirectoryURL.appending(path: "Generated")

        // Discover output files by running the generator with --list-outputs
        let outputFiles = try discoverOutputFiles(
            generator: generator.url,
            outputDir: outputDir
        )

        // Use a build command - runs when outputs are missing or inputs changed
        // Since there are no file inputs (we introspect libvips at runtime),
        // this will run when outputs are missing (first build after clone)
        return [
            .buildCommand(
                displayName: "Generating VIPS Swift wrappers",
                executable: generator.url,
                arguments: [
                    "--output-dir", outputDir.path(),
                    "--verbose"
                ],
                inputFiles: [],
                outputFiles: outputFiles
            )
        ]
    }

    /// Discover output files by running the generator with --list-outputs
    private func discoverOutputFiles(generator: URL, outputDir: URL) throws -> [URL] {
        let process = Process()
        process.executableURL = generator
        process.arguments = ["--list-outputs", "--output-dir", outputDir.path()]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // Suppress stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw PluginError.generatorFailed(status: process.terminationStatus)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw PluginError.invalidGeneratorOutput
        }

        // Parse output - one file path per line
        let filePaths = output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }

        return filePaths
    }
}

enum PluginError: Error {
    case generatorFailed(status: Int32)
    case invalidGeneratorOutput
}
