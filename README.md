# Clauthier

Clothe thine claude.

Plugins:
* [cdocs](plugins/cdocs/): Structured development documentation: devlogs, proposals, reviews, and reports.
* [browser-delegate](plugins/browser-delegate/): A sonnet leaf agent that drives named `@playwright/cli` browser sessions and reports artifacts and mechanical facts.

## Normal Installation

cdocs is intended to leave behind artifacts and records of its processes, thus should be installed at the project level:
```bash
claude plugin marketplace add weftwiseink/clauthier
claude plugin install cdocs@clauthier --scope project
```

## Local Installation

Prob don't want to do this unless you're @micimize - intended for dogfooding:
```bash
echo "
NOTE: if using containers and mounting ~/.claude, you'll need to mount the marketplace to the EXACT same path.
cloning into into '`pwd`/clauthier'
"
git clone git@github.com:weft/clauthier.git
claude plugin marketplace add ./clauthier
claude plugin install cdocs@clauthier --scope project
```
