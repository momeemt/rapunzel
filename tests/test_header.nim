import unittest
import rapunzel

proc getHtmlContentsFromAssetsHeaders (name: string): string =
  block:
    let
      path = "tests/assets/headers/" & name & ".html"
      file = open(path, fmRead)
    defer:
      file.close()
    result = file.readAll()

test "Header command":
  const rapunzel = """
{* Header1}
{** Header2}
{*** Header3}
{**** Header4}
{***** Header5}
{****** Header6}
"""
  check rapunzel.parseRapunzel.astToHtml().formatHtml() == getHtmlContentsFromAssetsHeaders("header")

test "Wrong Header command":
  const rapunzel = "{*? Header1}"
  expect UndefinedCommandDefect:
    discard rapunzel.parseRapunzel.astToHtml()
