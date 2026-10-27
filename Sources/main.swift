import Foundation

let output = AppComposition.commands().run(CommandLine.arguments)
if !output.stdout.isEmpty { print(output.stdout) }
if !output.stderr.isEmpty { fputs(output.stderr + "\n", stderr) }
exit(output.status)
