# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest, strformat, times

import oz

test "Converting bold commands":
  const ozWithBoldCommands = "normal [* bold] normal"
  check ozWithBoldCommands.ozParse.astToHtml() == "<p>normal <b>bold</b> normal</p>"

test "Converting italic commands":
  const ozWithBoldCommands = "normal [/ italic] normal"
  check ozWithBoldCommands.ozParse.astToHtml() == "<p>normal <em>italic</em> normal</p>"

test "Converting variable commands":
  const ozWithBoldCommands = "normal [% title, momeemt's blog] normal"
  check ozWithBoldCommands.ozParse.astToHtml() == "<p>normal  normal</p>"

test "Converting expand commands":
  const ozWithBoldCommands = "normal [= title] normal"
  check ozWithBoldCommands.ozParse.astToHtml() == "<p>normal momeemt's blog normal</p>"

test "Converting block variable commands":
  const ozWithBoldCommands = "{% foo, momeemt's blog}"
  check ozWithBoldCommands.ozParse.astToHtml() == ""

test "Fail to convert expand commands":
  const ozWithBoldCommands = "normal [= undefinedVar] normal"
  expect KeyError:
    discard ozWithBoldCommands.ozParse.astToHtml()

test "Fail to reassignment variable":
  const ozWithBoldCommands = "{% foo, someone's blog}"
  expect ReassignmentDefect:
    discard ozWithBoldCommands.ozParse.astToHtml()

test "Newline":
  const ozWithBoldCommands = """
foo
bar"""
  check ozWithBoldCommands.ozParse.astToHtml() == "<p>foo</p><p>bar</p>"

test "Complex converting":
  const ozWithBoldCommands = """
{% name, momeemt}
Hi, I'm [= name].
I like [* computer science].
[= now]"""
  check ozWithBoldCommands.ozParse.astToHtml() == &"<p>Hi, I'm momeemt.</p><p>I like <b>computer science</b>.</p><p>{times.now().format(\"yyyy-MM-dd HH:mm:ss\")}</p>"
