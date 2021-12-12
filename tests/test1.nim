# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest, strformat, times

import mountup

test "Converting bold commands":
  const mtUpWithBoldCommands = "normal [* bold] normal"
  check mtUpWithBoldCommands.mtupParse.astToHtml() == "<p>normal <b>bold</b> normal</p>"

test "Converting italic commands":
  const mtUpWithBoldCommands = "normal [/ italic] normal"
  check mtUpWithBoldCommands.mtupParse.astToHtml() == "<p>normal <em>italic</em> normal</p>"

test "Converting variable commands":
  const mtUpWithBoldCommands = "normal [% title, momeemt's blog] normal"
  check mtUpWithBoldCommands.mtupParse.astToHtml() == "<p>normal  normal</p>"

test "Converting expand commands":
  const mtUpWithBoldCommands = "normal [= title] normal"
  check mtUpWithBoldCommands.mtupParse.astToHtml() == "<p>normal momeemt's blog normal</p>"

test "Converting block variable commands":
  const mtUpWithBoldCommands = "{% foo, momeemt's blog}"
  check mtUpWithBoldCommands.mtupParse.astToHtml() == ""

test "Fail to convert expand commands":
  const mtUpWithBoldCommands = "normal [= undefinedVar] normal"
  expect KeyError:
    discard mtUpWithBoldCommands.mtupParse.astToHtml()

test "Fail to reassignment variable":
  const mtUpWithBoldCommands = "{% foo, someone's blog}"
  expect ReassignmentDefect:
    discard mtUpWithBoldCommands.mtupParse.astToHtml()

test "Newline":
  const mtUpWithBoldCommands = """
foo
bar"""
  check mtUpWithBoldCommands.mtupParse.astToHtml() == "<p>foo</p><p>bar</p>"

test "Complex converting":
  const mtUpWithBoldCommands = """
{% name, momeemt}
Hi, I'm [= name].
I like [* computer science].
[= now]"""
  check mtUpWithBoldCommands.mtupParse.astToHtml() == &"<p>Hi, I'm momeemt.</p><p>I like <b>computer science</b>.</p><p>{times.now().format(\"yyyy-MM-dd HH:mm:ss\")}</p>"