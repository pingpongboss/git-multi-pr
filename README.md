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

## Installation and getting started

Assuming that `$HOME/bin` is in your `$PATH`, clone the repository and create a link to the script in `$HOME/bin`.

```
$ mkdir -p $HOME/.git-multi-pr $HOME/bin; \
git clone git@github.com:pingpongboss/git-multi-pr.git $HOME/.git-multi-pr 2> /dev/null || git -C $HOME/.git-multi-pr pull; \
ln -s -f $HOME/.git-multi-pr/git-multi-pr $HOME/bin/git-multi-pr; \
chmod +x $HOME/bin/git-multi-pr
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

**List changes and pull from remote**

```
$ git-multi-pr list
$ git-multi-pr sync
```

**Make changes**

You can manage your local changes *any way you want*. You can use a GUI like [Tower](https://www.git-tower.com/), interactive git rebase on the command line, or `git-multi-pr` helper utilities.

```
$ git-multi-pr edit [optional_sha]
$ git-multi-pr continue
$ git-multi-pr abort

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

This new change will eventually be exported as its own PR. 

First, checkout the feature branch. Then, simply make your changes and create a commit.

```
$ git-multi-pr new-feature [feature-name]
$ vim file.java
$ git commit -a
```

The commit message will be used to populate the PR title and summary.

### Edit the latest change

Just amend a commit to update the latest change. You'll only need vanilla git commands here.

```
$ vim file.java
$ git commit -a --amend
```

If you notice extra metadata like `GIT_MULTI_BRANCH=` and `PR=` in the commit message, don't remove or edit those! `git-multi-pr` uses that metadata for bookkeeping.

### Start another change on the same feature branch

This second change will eventually be exported as a separate PR.

Make sure you've checked out the right feature branch. Then just create a new commit!

```
$ git-multi-pr new-feature [feature-name]
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

You can see the sha and title of each commit. When you use the tool later to export each change to a separate PR, this command will also show you the urls of each PR.

### Pull remote changes from master

Every once in a while, you may need to sync with origin/master to pull in changes made by others.

```
$ git-multi-pr sync
```

### Export your changes to PRs

When you're ready to export your work for reviewers to look at (don't forget to double check with `git-multi-pr list`), the tool will take a snapshot of all the local changes and create PRs from them. If you've previously exported PRs for some of the commits, they will be updated instead.

```
$ git-multi-pr export
```

> Make sure you do not make any changes while the tool takes a snapshot of all the local changes.

Each one of your local changes should now be exported to separate PRs. Open them in your browser to ensure that the contents are as expected. Note that Github will show strange branch names, and some PRs have a base that is not master. This is all done automatically by the tool to ensure that reviewers only see the incremental diffs for each change.

> You may notice that the PR's title and description is overwritten by the tool every time you export. These come from your local commit message, so amend your local commits to change them.

### Send your PRs out for review

You can add reviewers to the PRs using Github's web interface. When you receive comments and need to make changes, follow the [Edit a previous change](#edit-a-previous-change) instructions to make those edits to the corresponding commits. Once those changes have been made, run `git-multi-pr export` again to update the PRs with a snapshot of your changes.

**Do not merge the PRs using the web interface yet.**

### Merge the PRs

PRs are merged *in order* from oldest to newest, one at a time. Check the order of PRs with `git-multi-pr list`. You cannot merge the PRs out of order.

Once the oldest PR is approved, you can now use the tool to merge it. The tool will only merge one PR at a time.

```
git-multi-pr merge
```

> TODO: You may notice some non-sensical messages being added to the PR, instead of the PR being merged. If it doesn't make sense to you, don't worry - this tool was initially created internally. You can safely ignore the messages, and click on the Merge button in Github's web interface. Remember to only do this after running `git-multi-pr merge`!

After you've verified that the PR has been merged, you can now update your feature branch to reflect that.

```
git-multi-pr sync
git-multi-pr list
```

You should see that your local changes is now missing the oldest change. It's now part of master!

### Edit a previous change

So you received some review feedback on one of your older PRs. How do you edit that change? You may already know several ways modify your local commit history.

> Advanced git users can use interactive rebase to manage their local git history. Identify which commit you want to make changes to, use `rebase -i` to choose edit that commit, make your changes and amend them to that commit, and then use `rebase --continue` to exit interactive rebase.

> You can also use a GUI like [Tower](https://www.git-tower.com/) to modify your local commit history.

If you don't have experience with either of those options, `git-multi-pr` provides some utilities that you can use.

First, identify which change you want to edit, and enter edit mode for that commit. This is also called `rebase` mode.

```
$ git-multi-pr list
# Copy the commit sha of the change you want to edit.
$ git-multi-pr edit [sha]
```

You'll notice that while you're in rebase mode, the commit you've chosen to edit will be at HEAD.

```
$ git-multi-pr list
# Notice how HEAD is now at the commit you're editing.
```

Make some changes and amend it to HEAD.

```
$ vim file.java
$ git commit -a --amend --no-edit
```

Finally, finish by exiting rebase mode.

```
$ git-multi-pr continue
```

At this point, you may be asked to resolve some conflicts. *This is normal* and will happen if your changes happen to touch the same lines. If you mess up at any time and want to forcefully exit rebase mode, you can do `git-multi-pr abort`. This will return you to the state you were in before you ran `git-multi-pr edit`, but beware that this may mean losing your work while you were in rebase mode!

Once you're happy with your local commit history, you can export another snapshot, which will update the PRs for those changes.

```
$ git-multi-pr list
# Verify that everything looks good.
$ git-multi-pr export
```

## Advanced usage

TODO

### Reordering your changes

If you want to merge your PRs in a different order, you can follow the [Edit a previous change](#edit-a-previous-change) instructions to *rearrange* the order of your local commits, so that you may merge the PRs in the order that you like. Don't forget to export a new snapshot after rearranging your local changes.

> Reordering commits may require you to do some complicated conflict resolution. The recommendation for new users is to encourage your reviewers to take a look at your PRs in the order that you exported them.

## How it works

TODO
