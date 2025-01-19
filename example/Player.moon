-- -------------------------------
--** @brief Player Class
--** Extends <b>Example</b>
--**

Example = assert require "Example"

local VERSION
VERSION = '1.0.1'


class Player extends Example
  new = (x, y) =>
    --** @method public new (x, y)
    --** @brief Example class constructor
    --** @param x a number
    --** @param y a number
    super x, y

