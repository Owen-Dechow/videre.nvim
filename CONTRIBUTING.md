# Contributing

Contributions to this software are greatly appreciated. Here are some
guidelines to help your contribution go smoothly.

## 🧠 Open an Issue First

Before submitting a pull request (PR), please open an issue describing the
bug or feature you want to address so it can be discussed first.

> [!NOTE]
> Some features may be beyond the scope of this software and will not be
> added.

Opening an issue first ensures you don't spend time developing something
that falls outside the plugin's scope.

## 🔍 Keep Changes Scoped and Focused

Each PR should address one topic. Small, unrelated fixes are welcome
alongside the main change (for example, fixing a typo), but a PR that
only adds a period to the end of a sentence is not worth the review time.

For instance, in a PR that adds YAML support:
* ✅ Fixing a typo in `README.md` is okay.
* ❌ Refactoring unrelated rendering code is not okay. It is a significant
  change that is unrelated to YAML support and belongs in its own PR.

## 🤝 Be Respectful & Collaborative

* Communicate clearly and professionally.
* Do not use profanity in code, comments, or discussion. **Use of profanity
  will not be tolerated.**

## 🧪 Use Type Annotations

Please annotate new and changed code with LuaLS-style type annotations
(`---@param`, `---@return`, `---@type`, etc.), as the rest of the codebase
does. It makes the code easier to read, review, and maintain.

## 📂 Test Example Files

The `test` directory contains example data files (`test.json`, `test.toml`,
`test.xml`, and `test.yaml`) for trying out the plugin. There is no
automated test suite. To check your changes, open one of these files (or
your own) and run `:Videre`.

> [!IMPORTANT]
> If you add support for a new data type, you **MUST** add a test example
> file for it to the `test` directory.

## 🧰 How to Contribute

* Open an issue (see above).
* Fork and clone the repository.
* Create a descriptively named branch.
* Make your changes and try them out on a few example files.
* Push your branch and submit a PR that references the issue.

## 🗣️ Questions & Discussions

If you have any questions, please don't hesitate to ask. Opening an issue
is the best way to do that.

## 🙏 Thank You

Thank you to everyone who has contributed to this project. Your time and
effort are genuinely appreciated.

Contributors:
* [Owen-Dechow](https://github.com/Owen-Dechow) (Owen Dechow)
* [carbon-steel](https://github.com/carbon-steel) (Roger Kim)
* [chrisgrieser](https://github.com/chrisgrieser) (Chris Grieser)
* [emrearmagan](https://github.com/emrearmagan) (Emre Armagan)
* [TommyDuc](https://github.com/TommyDuc) (Tommy Duchesne)
* [KihoChoiLGE](https://github.com/KihoChoiLGE) (KihoChoiLGE)
