# git-multi-pr

`git-multi-pr` is a tool that allows you to work on multiple PRs within a single git branch. Every commit in your local history is exported out to separate PRs, each containing only the changes in its corresponding commit to make it easy for your reviewers to view and provide feedback.

`git-multi-pr` is based on the popular [amend/rebase mutable-history workflow](https://secure.phabricator.com/w/guides/arcanist_workflows/#facebook-workflow). The main benefit of this workflow is how easily it allows you split a large feature into multiple changes that depend on each other. You may have tried to do this with vanilla git by creating branches off of other branches, and rebasing branches on top of each other to "ripple through" any changes. This workflow automates all that manual bookkeeping by taking advantage of the natural stack of dependencies created by the linear commit history in a single branch.

This workflow is adopted by engineers in several large companies, the major ones being Facebook and Google.
- Arcanist: Internal tool built by Facebook for code reviews on Phabricator repositories. Arcanist relies heavily on this workflow.
- Git-Multi: Internal tool built by Google that implements the same workflow, but for its internal Google3 repository.

`git-multi-pr` brings the power of this workflow to Github!

## Philosophy

The general workflow philosophy is that *each change is represented by one commit*. 

> A change will reviewed as a single PR. A simple feature can often be represented by a single change, but complex features should be split into multiple changes for the sanity of your reviewers.

Because each change is only associated with a single commit (and commit message), *further modifications to the code or message are amended to that commit*. With this workflow, you'll no longer litter your local history with "fixit" commits. No more "oops", "fix tests", and "fix tests again".

To start a change that depends on another change, just create another commit in the same branch.

To modify a previous change, you'll use the power of interactive rebase to edit a previous commit. The magic of rebase is that when you amend that previous commit and continue out of interactive rebase, your modifications automatically ripple through the stack of local commits.

Finally, when your changes look good, `git-multi-pr` will take a snapshot of each local commit and create a PR for each one. Any modifications since the last snapshot will be reflected in the PRs.

## Getting started

## Basic usage

## Advanced usage

## How it works
