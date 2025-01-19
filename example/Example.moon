
--** @brief Example class

window = assert require "window"
context = assert require "context"

local VERSION
VERSION = '1.0.1'


add = (x, y) ->
  --** @method public add (x, y)
  --** @brief adds two integers
  --** @param x a number
  --** @param y a number
  --** @return return the addition of the two numbers
  x + y

_sub = (x, z) =>
  return x - y

--** @var _scroll
--** If scrolling is enabled
_scroll = true


class Example
  new = (x, y) =>
    --** @method public new (x, y)
    --** @brief Example class constructor
    --** @param x a number
    --** @param y a number
    @x = 0
    @y = 0

    return {}

  _move = (x, y, z) =>
    @x += x
    @y += y
