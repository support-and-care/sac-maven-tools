#!/usr/bin/env groovy

logger.info ("Creating report for concept '{}' in '{}' (#{} rows)", concept.id, reportDirectory, result.rows.size())

File output = new File(reportDirectory, "open-dependabot-PRs.adoc")
output.delete()
output.append("""= Open DependaBot PRs

The following projects have open Pull-Requests from DependaBot.

[cols="8,1", options="header"]
|===
| Title | Id

""")

def currentRepository = ""
result.rows.each {row ->
    def repository = row.columns['Repository'].value
    def url = row.columns['URL'].value
    if (repository != currentRepository) {
        currentRepository = repository
        output.append("2+| *${url}/pulls/dependabot%5Bbot%5D[${currentRepository}]* ")
    }
    output.append("| ${row.columns['Title'].value} | ${url}/pull/${row.columns['Id'].value}[${row.columns['Id'].value}] ")
//    output.append("| ${row.columns['NoofOpenDependabotPRs'].value}\n")
}

output.append("\n|===")
