<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [git-multi-pr](#git-multi-pr)
  - [Philosophy](#philosophy)
  - [Getting started](#getting-started)
  - [Cheat sheet](#cheat-sheet)
  - [Basic usage](#basic-usage)
    - [Start a new feature branch](#start-a-new-feature-branch)
    - [Start a new change](#start-a-new-change)
    - [Update a change](#update-a-change)
    - [Start a change which depends on another change](#start-a-change-which-depends-on-another-change)
    - [List the changes in a feature branch](#list-the-changes-in-a-feature-branch)
    - [Edit a previous change](#edit-a-previous-change)
    - [Sync your feature branch with master](#sync-your-feature-branch-with-master)
    - [Export your changes to PRs](#export-your-changes-to-prs)
    - [Add reviewers, iterate on the PRs, and get approval](#add-reviewers-iterate-on-the-prs-and-get-approval)
    - [Merge the PRs](#merge-the-prs)
  - [Advanced usage](#advanced-usage)
    - [Reordering your changes](#reordering-your-changes)
  - [How it works](#how-it-works)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

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

First, install the script somewhere in your $PATH.

```
$ mkdir -p $HOME/bin ; curl -o $HOME/bin/git-multi-pr https://raw.githubusercontent.com/pingpongboss/git-multi-pr/master/git-multi-pr ; chmod +x $HOME/bin/git-multi-pr
```

Then, make sure all dependencies are installed.

```
$ git-multi-pr status
```

> Take a look at the [open bugs](https://github.com/pingpongboss/git-multi-pr/issues?utf8=%E2%9C%93&q=is%3Aissue+is%3Aopen+label%3Abug) for what to avoid. At the moment, there are a few gotchas that have to do with the script being written in bash. In general, branch names cannot include `/` and commit messages should avoid special characters like `$` `[` `]` due to buggy bash/json string evaluation.

## Cheat sheet

**Start a new feature branch**

```
$ git-multi-pr new-feature [feature-name]
```

**List changes and make edits**

```
$ git-multi-pr list
$ git-multi-pr sync
$ git-multi-pr edit
$ git-multi-pr continue

$ git commit -a # For making a new change
$ git commit -a --amend # For editing an existing change
```

**Export and merge PRs**

```
$ git-multi-pr export
$ git-multi-pr merge
```


## Basic usage

### Start a new feature branch

A feature branch is a group of related changes that you'll manage together. *Feature branches do not have any dependencies on other featur branches.* When creating a new change, think about which feature branch it should belong in.

```
$ git-multi-pr new-feature [feature-name]
```

This creates a new feature branch. You may jump between features using `git checkout [feature-name]`.

### Start a new change

Make sure you're working in the right feature branch. Then, simply make your changes and create a commit. You'll only need vanilla git commands here.

```
$ git checkout [feature-name]
$ vim file.java
$ git commit -a
```

The commit message will be used to populate the PR title and summary.

### Update a change

Just amend a commit to update that change. You'll only need vanilla git commands here.

```
$ vim file.java
$ git commit -a --amend
```

If you notice extra metadata like `GIT_MULTI_BRANCH=` and `PR=` in the commit message, don't remove or edit those! `git-multi-pr` uses that metadata for bookkeeping.

### Start a change which depends on another change

Just create a new commit! You'll only need vanilla git commands here.

```
$ vim file.java
$ git commit -a
```

The commit message will be used to populate the PR title and summary.

### List the changes in a feature branch

You'll want to run this command often to sanity check your local changes.

```
$ git-multi-pr list
```

The output looks like:

```
Local changes for feature-name:
18983 https://github.com/user/repo/pull/4 (HEAD -> feature-name) Added animations
b0e2a https://github.com/user/repo/pull/3 Added additional functionality
368a3 https://github.com/user/repo/pull/2 Initial change for feature X
```

You can see the sha and title of each commit. When you use the tool later to export each change to a separate PR, this command will also show you the urls for each PR.

### Edit a previous change

To edit a previous change, we're going use the power of interactive rebase.

> Advanced git users can just skip this section - you can use `rebase -i` to choose which commit to edit, make your changes and amend them to that commit, and then use `rebase --continue` to exit interactive rebase.

First, choose which commit you want to edit. This will enter you into rebase mode with the chosen commit at your HEAD.

```
$ git-multi-pr edit
# Now, pick "edit" for the commit you want to edit.
```

Then, while you're in rebase mode, make some changes and amend it to the commit at HEAD.

```
$ vim file.java
$ git commit -a --amend
```

Finally, finish by exiting rebase mode.

```
$ git-multi-pr continue
```

At this point, you may be asked to resolve some conflicts. *This is normal* and will happen if your changes happen to touch the same lines. If you mess up at any time and want to forcefully exit rebase mode, you can do `git-multi-pr abort`. This will return you to the state you were in before you ran `git-multi-pr edit`, but beware that this may mean losing your work!

### Sync your feature branch with master

Every once in a while, you may need to sync with master to pull in changes made by others.

```
$ git-multi-pr sync
```

You may be asked to resolve some conflicts. *This is normal* and will happen if any of your changes happen to touch the same lines as changes on master.

### Export your changes to PRs

When you're ready to export your work for reviewers to look at (don't forget to double check with `git-multi-pr list`), the tool will take a snapshot of all the local changes and create PRs from them.

```
$ git-multi-pr export
```

> Make sure you do not make any changes while the tool takes a snapshot of all the local changes.

Each one of your local changes should now be exported to separate PRs. Open them in your browser to ensure that the contents are as expected. Note that the PRs are created from auto-generated remote branches, and some PRs have a base that is not master. This is all done automatically by the tool to ensure that reviewers only see the relevant diffs for each change.

> TODO: You may also notice some non-sensical messages being added to the PR. If it doesn't make sense to you, don't worry - this tool was initially created internally. You can safely ignore them.

### Add reviewers, iterate on the PRs, and get approval

You can add reviewers to the PRs using Github's web interface. When you receive comments and need to make changes, follow the [Edit a previous change](#edit-a-previous-change) instructions to make those edits to the corresponding commits. Once those changes have been made, run `git-multi-pr export` again to update the PRs with your changes.

**Do not merge the PRs using the web interface yet.**

### Merge the PRs

Note that PRs are merged based on the last snapshot taken by the `git-multi-pr export` command. If you've made further changes, you must export a new snapshot before you attempt to merge.

You must merge the PRs *in order* from oldest to newest, one at a time. The order is given by the `git-multi-pr list` command. You cannot merge the PRs out of order.

Once the oldest PR is approved, you can use the tool to merge it. The tool will only merge one PR at a time.

```
git-multi-pr merge
```

> TODO: You may notice some non-sensical messages being added to the PR, instead of the PR being merged. If it doesn't make sense to you, don't worry - this tool was initially created internally. You can safely ignore the messages, and click on the Merge button in Github's web interface. Remember to only do this after running `git-multi-pr merge`!

After you've verified that the PR has been merged, you can now update your feature branch to reflect that.

```
git-multi-pr sync
git-multi-pr list
```

You should see that your local changes is now missing the oldest change. It's now part of master! If you have additional local changes, you can edit them, export them, or merge them by following these and previous instructions.

## Advanced usage

TODO

### Reordering your changes

If you want to merge your PRs in a different order, you can follow the [Edit a previous change](#edit-a-previous-change) instructions to *rearrange* the order of your local commits, so that you may merge the PRs in the order that you like. Don't forget to export a new snapshot after rearranging your local changes.

> Reordering commits may require you to do some complicated conflict resolution. The recommendation for new users is to encourage your reviewers to take a look at your PRs in the order that you exported them.

## How it works

TODO
