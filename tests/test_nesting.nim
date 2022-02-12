import unittest
import rapunzel

proc getHtmlContentsFromAssetsNesting (name: string): string =
  block:
    let
      path = "tests/assets/nesting/" & name & ".html"
      file = open(path, fmRead)
    defer:
      file.close()
    result = file.readAll()

test "inline-nest command":
  const rapunzelNest1 = "Hello, [* [/ Rapunzel]]!"
  const rapunzelNest2 = "Hello, [~ [* [/ Rapunzel]]]!"
  check rapunzelNest1.rapunzelParse.astToHtml() == getHtmlContentsFromAssetsNesting("inline-nest1")
  check rapunzelNest2.rapunzelParse.astToHtml() == getHtmlContentsFromAssetsNesting("inline-nest2")

test "block command including newline":
  const rapunzel = """
{*
  Header1
}
"""
  check rapunzel.rapunzelParse.astToHtml().formatHtml() == getHtmlContentsFromAssetsNesting("inc-nl-block1")

test "block-inline-nest command":
  const rapunzel = """
{*
  [/ Header1]
}
"""
  check rapunzel.rapunzelParse.astToHtml().formatHtml() == getHtmlContentsFromAssetsNesting("block-inline-nest1")
