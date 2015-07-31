# Examples #

Below are some brief usage examples (**NOTE** I haven't made it pretty to use via irb yet -- it'll spit out _tons_ of `inspect` data):

This example creates a yellow png with a width of 10 and a height of 20 and half transparency.  For now, you might want to comment out in formats/png.rb the different png chunks you don't need/want.  Eventually I'll add in a more elegant way to exclude defined fields.

```
# formats/png.rb

class Png < Funder
    field :png_header, Str, "\211PNG\r\n\032\n"
    field :ihdr, IHDR
    # field :chrm, CHRM
    field :srgb, SRGB
    # field :sbit, SBIT
    # field :trns, TRNS
    # field :gama, GAMA
    # field :splt, SPLT, nil, :mult=>true, :mult_max=>2
    # field :bkgd, BKGD
    # field :plte, PLTE
    # field :hist, HIST
    # field :phys, PHYS
    # field :time, TIME
    field :idat, IDAT
    # field :text, TEXT, nil, :mult=>true, :mult_max=>2
    # field :ztxt, ZTXT, nil, :mult=>true, :mult_max=>2
    # field :itxt, ITXT, nil, :mult=>true, :mult_max=>2
    field :iend, IEND
end
```

This is how I would create the previously described image:

```
require 'formats/png'

p = Png.new

p.ihdr.data.width.value      = 10
p.ihdr.data.height.value     = 20
p.ihdr.data.color_type.value = 6
p.idat.data.alpha.value      = 0x80
p.idat.data.red.value        = 0xff
p.idat.data.green.value      = 0xff
p.idat.data.blue.value       = 0x00

File.open("test.png", "w") { |f| f.write p.to_out }
```

Note that I didn't have to explicitly set the width and height of the actual pixel data in the IDAT chunk.  This is taken care of with lines 26,27,35, and 36:

```
 # formats/png.rb

 23 class IDAT < Chunk
 24     field :type_code, Str, "IDAT"
 25     section(:data, action(ZlibDeflate)) do
 26         unfield :height, Int, nil, :p=>'c'
 27         unfield :width, Int, nil, :p=>'c'
 28         unfield :alpha, Int, 255
 29         unfield :red, Int, 255
 30         unfield :green, Int, 255
 31         unfield :blue, Int, 255
 32         unfield :color_type, Int
 33 
 34         field :pixel_data, Str, lambda {
 35             w = width.value || @parent.parent.ihdr.data.width.value || rand(10)+1
 36             h = height.value || @parent.parent.ihdr.data.height.value || rand(10)+1
 37             c_type = color_type.value || @parent.parent.ihdr.data.color_type.value || 2
 38             case c_type
 39             when 2 # true color
 40                 h.times.map do
 41                     "\x00" +
 42                     w.times.map do
 43                         r = red.value || rand(256)
 44                         g = green.value || rand(256)
 45                         b = blue.value || rand(256)
 46                         r.chr + g.chr + b.chr
 47                     end.join
 48                 end.join
 49             when 6 # true color w/ alpha
 50                 h.times.map do
 51                     "\x00" +
 52                     w.times.map do
 53                         r = red.value || rand(256)
 54                         g = green.value || rand(256)
 55                         b = blue.value || rand(256)
 56                         a = alpha.value || rand(255)
 57                         r.chr + g.chr + b.chr + a.chr
 58                     end.join
 59                 end.join
 60             else
 61                 h.times.map do
 62                     "\x00" +
 63                     w.times.map do
 64                         r = red.value || rand(256)
 65                         g = green.value || rand(256)
 66                         b = blue.value || rand(256)
 67                         r.chr + g.chr + b.chr
 68                     end.join
 69                 end.join
 70             end
 71         }
 72     end
 73 end
```

You _can_ explicitly set a different height/width than what is defined in the IHDR chunk.

`formats/png.rb` was my guinea-pig for developing all of the functionality and syntactic sugar.  Looking over how it works will explain a lot.  I don't think I'll be adding any other data-formats I've defined to the repository though.  Gotta leave you some of the fun :^)

Here's a basic example on how to define a data format with `Funder`:

```
class A < Funder
    field :NAME, CLASS, VALUE [, OPTIONS]
end
```

You'll also notice that inheritance works quite nicely, as seen in the example below, as well as in `formats/png.rb` where it is used to define the basic structure of a chunk:

```
class Item < Funder
    field :name, Str
    field :description, Str
    field :price, Int, 0, :p=>'c'
end

class Lightsaber < Item
    field :name, Str, "sword"
    section :description do
        field :color, Str, "green"
        field :charge, Int, 87
        field :previous_owner, Str, "Skywalker"
    end
    field :price, Int, 123, :p=>'f'
end
```

Other functionality of note are actions, sections, conditional logic (`If` action), lambdas for values of fields, and unfields.  I'll explain these more in a later example.