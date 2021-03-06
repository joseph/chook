# chook

A very simple reference reader for Zhook ebooks.

Invented by [Inventive Labs](http://inventivelabs.com.au). Released under the
MIT license.

More info: http://ochook.org


## What is this?

It's a reference implementation of a Reading System that is compliant with
the [Zhook ebook specification](http://gist.github.com/480901).

For more information about the genesis of that ebook specification, read
our [weblog entry](http://is.gd/dzjFS).


## Requirements

* Ruby
* Rubygems:
  - Rack 1.0 or 1.1
  - Sinatra 1.0
  - Nokogiri


## How to run

From the chook directory, invoke the rackup command provided by Rack:

    $ rackup

Alternatively, start it up the sinatra way:

    $ ruby chook.rb


## How to use

Go to /publish to upload a Zhook file. This will convert it to an Ochook URL
(ie, an unzipped Zhook file with an offline cache manifest -- see the Zhook
specification).

Ochooks are stored in /public/books. If you want to return to an Ochook later,
you can construct its native URL as: /books/[id]. And its reader URL will be:
/read/[id].


## Zhook-required documentation for chook

The Zhook specification asserts that certain aspects of the Reading System
should be documented. This is that documentation.


### RS HTML element ID

* RS:org.ochook.reader


### Recognised metadata names

Pretty much the Dublin Core set:

* title
* identifier
* isbn
* language
* creator
* subject
* description
* publisher
* contributor
* date
* source
* relation
* coverage
* rights

### CSS supported

As a browser-based reader, the chook reader supports whatever CSS properties
are implemented in the browser used to access it. No CSS properties are
stripped by the reader.


### DOM modifications

None.


### Microformats

None (yet!).


### Contents

A Table of Contents display is planned for the chook reader, but nothing is
yet implemented.


### Scripting

Script tags and event handler attributes in the ebook are unharmed: they're
permitted and executed as usual.
