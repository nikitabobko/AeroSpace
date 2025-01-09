# Contributing

Look who wants to contribute! Nice to see you here, let me show you what you can do :)

## Submit bugs and feature ideas

Submit bugs to https://github.com/nikitabobko/AeroSpace/discussions/categories/potential-bugs
Submit feature ideas to https://github.com/nikitabobko/AeroSpace/discussions/categories/feature-ideas

Rules:
* Search for duplicates (in GitHub Issues and Discusssions) before creating a new discussion
* Upvote for issues/discussions that you find useful

**Consider including in bug reports**

* `aerospace debug-windows` output, if the problem is about handling some windows
* Screenshots of problematic windows
* Videos of problematic windows
* What did you try to resolve the issue?
* Your config
* AeroSpace version
* macOS version

**Consider including in feature request**

* Use cases!
* Did I mention use cases?
* Alternative approaches
* Links to docs of similar features in other window managers that you know
* Synopsis, if you suggest a new command
* Mental model description

## Users cannot create GitHub Issues directly

Users are not allowed to create Issues directly in this repository - we ask that you create a Discussion first.

Users can't create issues directly because:
- Users submit too many duplicates without prior search
- A lot of user issues are misunderstandings, environmental problems, or configuration errors by the users themselves
- Few people can formulate proper bug reports
- Even fewer people can formulate proper, actionable feature requests that align with other existing/planned features and the overall AeroSpace mental model

Any Discussion which clearly identifies a problem and can be confirmed or reproduced will be converted to an Issue by maintainers.

This whole pattern makes it easier for maintainers or contributors to find issues to work on.
Issues are like a publicly observable maintainers' inbox.
We want to keep this inbox tidy and clean.

## Discuss issues/discussions

One of the most useful thing you can do is to discuss issues/discussions.

Imagine that you were assigned to fix the issue.
Try to suggest the best approach and design on how to fix the issue.
Suggest the synopsis/config format, reason in written form what is good about it, what is bad about it, what are the alternatives, etc.
Basically, see the "Prior discussion" section in [Submit Pull Requests](#submit-pull-requests) :)

If you have something to contribute to the conversation. Do it!

Please keep the conversation to the point. Discuss one issue at a time, crossreference other issues

You can take a look at the following issues:

* Most voted issues: https://github.com/nikitabobko/AeroSpace/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%2B1-desc
* Sometimes conversations happen on old issues that aren’t yet closed. See https://github.com/nikitabobko/AeroSpace/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc
* Issues that are unclear on how to fix, or issues that require design of the interface (CLI or config interface) are tagged with `design-needed` tag https://github.com/nikitabobko/AeroSpace/issues?q=is%3Aissue+is%3Aopen+label%3Adesign-needed

## Submit Pull Requests

**Prior discussion**. For non-trivial changes (such as user visible changes), it's always better to ask for prior approval and discuss what you want to do before doing it.

Please create a new discussion and describe you want to do.

Consider including

* What users will observe after your change?
* Feature interaction with existing features or potential future features
* What use cases does it cover
* What is the proposed syntax for the config
* What is the proposed synopsis of CLI command
* How you think it should be implemented (if you can describe it)
* etc.

Discussing that you want to do something doesn't put any obligations on you. If you don't want to start the discussion just because you're afraid that you won't do it. Don't be afraid!

Small and trivial improvements can be submitted without any discussion.

**Commit hygiene**. Each submitted commit must be atomic change (a Pull Request may contain several commits). Don't introduce new functional changes together with refactorings in the same commit.

Similarly, when implementing features and bug fixes, please stick to the structure of the codebase as much as possible and do not take this as an opportunity to do some "refactoring along the way".

A good commit message also mentions the motivation of the change (the commit describes what, why and how)

**License Agreement**. By contributing changes to this repository, you agree to license your contributions under the MIT license.

Maintainers can merge your pull request with arbitrary modifications.

**Pull request merge**. It cannot be guaranteed that your pull request will be merged.
Be ready that your pull request might be rejected because the implementation isn't good, or the approach is incorrect.

The prior discussion is here for you to minimize the risk of rejection.

## Spread the word

Do you like the project? Does AeroSpace finally fix your problems with windows management on macOS? Good to hear it!

* Spread the word in social networks! (Don't forget to share the link :) )
* Talk about AeroSpace to your colleagues and friends
* Write a blogpost about your workflows
* Record a YouTube video

## Share your workflow and tips

Submit your tips to [the Goodies page](https://nikitabobko.github.io/AeroSpace/goodies). The source code of the page can be found in `./docs` directory

## Support the project financially

Supporting the project financially counts as a contribution (even if it's just a $1/month). https://github.com/sponsors/nikitabobko
