# Intro #

This wiki page is designed to get you up to speed so you can use `Funder`. Links to more in-depth documentation
on different aspects of `Funder` are listed below:

  * http://code.google.com/p/funder/wiki/Fields
  * http://code.google.com/p/funder/wiki/Actions
  * http://code.google.com/p/funder/wiki/Inheritance

# Funder Description #

Funder (**F** ormat **UNDER** stander) is a Ruby library that can be used to define data-formats.  To make use of Funder,
you must make a Ruby class that descends from the Funder class.  I have always used PNG as my guinea pig for this project.
No need to stop now. (In case anybody wants to understand the PNG format better, w3c's specs are pretty good:
http://www.w3.org/TR/PNG/, as are libpng's at http://www.libpng.org/pub/png/libpng-1.4.0-manual.pdf)

```
require 'funder'

class Png < Funder
end
```

# Field #

Every data format is made up of fields.  To add a field to your class, you must call the static field method, defined
in `funder.rb` in the `Funder` class. The format for this is:

```
	field(name, klass, value=nil, options={})

	name    - a symbol (:name)
	klass   - a class that descends from Field
	value   - the default value
	options - any additional options
```

Calling the field method adds a new `PreField` instance that contains information about the field you would like to
make to the static `@order` variable for your class.  When it comes time for you to make an instance of your
Funder-derived class, every field value must be generated on the fly. Otherwise, if you made two instances of your
class, they would actually end up sharing the objects used in their fields.  This is the reason for the `PreField` instance.
The `PreField` class acts as a place-holder until an instance of your class is actually made.  At that point, the
`create` method is called on every `PreField` instance, which returns a new instance of the class you specified
with the `klass` variable.

The order in which you specify the fields is the order they will appear once you call the `to_out` method. I mentioned
the `@order` field before - this keeps track of the order fields are made in and is used to output the resulting
values in that order.  If you wanted to muck with the order of the fields, `@order` would be the thing to mess
with.

Moving on.

Every PNG image begins with the PNG header.  This is how I would define the header:

```
	require 'funder'

	class Png < Funder
		field :png_header, Str, "\211PNG\r\n\032\n"
	end
```

Besides the PNG header, a PNG image is made up of chunks, each having this general format:

```
	require 'funder'

	class Chunk < Funder
		field :length, Int, action(Length, lambda{[data]})
		field :type_code, Str, nil, :min=>4
		field :data, Str, nil
		field :crc, Int, action(Crc32, lambda{[type_code,data]})
	end
```

You'll notice I used two classes, `Str` and `Int`, as the klass with calls to `field`. All of the default `Field`-derived
classes can be found in `fields.rb`.  `Str` and `Int` are the only field classes directly available. If you look in
`fields.rb`, you might notice there is also a `MultField` class and a `Bool` class - these aren't meant to be used
directly;  we'll go over them later.

# Str #

The `Str` class is meant to handle strings.