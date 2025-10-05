#!/usr/bin/env groovy

logger.info ("Creating report for concept '{}' in '{}' (#{} rows)", concept.id, reportDirectory, result.rows.size())

File output = new File(reportDirectory, "open-dependabot-PRs.adoc")
output.delete()
output.append("""= Open DependaBot PRs

The following projects have open Pull-Requests from DependaBot as of ${new Date()}.

[cols="8,3,1", options="header"]
|===
| Title | Date | Id

""")

def currentRepository = ""
result.rows.each {row ->
    def repository = row.columns['Repository'].value
    def url = row.columns['URL'].value
    if (repository != currentRepository) {
        currentRepository = repository
        output.append("3+| *${url}/pulls/dependabot%5Bbot%5D[${currentRepository}]* ")
    }
    output.append("| ${row.columns['Title'].value} | ${row.columns['Date'].value} | ${url}/pull/${row.columns['Id'].value}[${row.columns['Id'].value}] ")
//    output.append("| ${row.columns['NoofOpenDependabotPRs'].value}\n")
}

output.append("\n|===")
