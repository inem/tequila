## Overview ##

Tequila basically is HAML for JSON generation.

Today while developing web applications with rich user UI, almost everything you need from rails backend is bunch of data in JSON format.

- Almost always, when you had to create unobvious set of data, your controllers became fat and ugly.

        @humans.to_json(
          :methods => [:login, :enhanced_name, :hello_world], :except => [:created_at, :updated_at],
          :include => {:pets => { :except => [:human_id, :pet_type_id, :created_at, :updated_at],
              :methods => :pet_type_name,
              :include => { :toys => { :methods => [:railsize2], :only => [:color, :size]} }
            }}
          )

- And you had to create a lot of small helper methods in your models if you want for example fullname instead of firstname, middlename and lastname or you want pretty address, instead of separate fields for zip, country, state and street adress in your JSON.
- And you had to create child node in your JSON for has-one or belongs-to associations if you want to get even one attribute form association.
- You cannot rename keys in your json. You might want to use keyword "type", but it is reserved by rails.
- What about calling your method with some parameters while generating JSON? No native way, sorry...

Tequila is an instrument, which lets easily move your JSON-generation logic from controllers to views. Take a look at features:

## Features ##

![Tequila features](http://inem.github.com/images/tequila-features.png)

- [Here is Jazz template](http://gist.github.com/173339/)
- [And here is it's JSON output](http://gist.github.com/173255/)

## Installation ##

./script/plugin install git://github.com/inem/tequila.git

After that drop some Tequila code into an apropriate template (should have .jazz extension) - and you are there!

## Examples ##

    -@humans => people
      :only
        .name => login
      :code => enhanced_name
        name + "!!!"
      :code => hello_world
        "Hello world!"
      +pets
        :except
          .human_id
          .pet_type_id
        +toys
          :methods
            .railsize("$", price.to_s)
        +pet_type
          :only
            .class_name

    -@humans => aa
      :except
        .name
      :code => super_name
        "→#{name}→"
      +pets
        :except
          .human_id
          .pet_type_id
        +toys
          :methods
            .railsize("$", price.to_s)
        +pet_type
          :only
            .class_name

    -@humans => humanoids
      :only
        .name => login
      :code => humanoid_names
        name + "is Humanoid"
      +pets => animals
        :only
          .human_id
          .name
        :code => humanoid_animals
          name + "is Humanoid pet"
        +toys
          :only
            .label
        <pet_type
          :only
            .class_name => pet_type

## Basic syntax ##

Have you ever used to_json method in your Rails app? If so, you should be familiar with basic Tequila syntax. You still have your :only, :except and :methods keywords. Instead of writing

    :include => { :association1 => {...}}

You should just remember that every variable definition must be started '-' and every association with '+'.     
So example above can be written much shortly:

    +association1

## Advanced ##

### Labels ###

Label can be defined via expression (=> label) which can be added everywhere where it makes sense. It means that you can add label to such elements as :code, +association, etc.. and can not add label to :except declaration and :gluening object. Some functionality of these features are covered by standart Rails to_json method and some aren't. For instance, if you bind alias 'animals' to assoication 'pets' it will automatically leads to bound 'animal' label to each Pet model below such declaration (see [example](http://gist.github.com/173255/))

### Call methods with params ###

It is pretty simple. You just can pass any amount of params in any method in :methods definition. You should not create any presenters for model methods if you want to call them with params. Want to use instance method as param? No problem! With a bit of Tequila magic you can simple do so:

    ...
    :methods
      .calculate(1,2,3, total_count)

### Code blocks ###

Code block are extremely useful if you need to add evaluable expression in the generated json but you don't want to store it as model (or presenter) method. For example you have attribute label, but for some reason you have to return "[# {label}]" just in one place of the code. The following feature allows you to keep your models clean:

    ...
    :code => plabel
      '[' + label + ']'
    end

As result, in the generated data structure you will have additional field 'plabel' with desired value.

### Gluing ###

It is another nice feature which you always want to have (may be instinctively ;). Sometimes you have 'belongs_to' association where you need just one attribute. And 'gluing' allows you to.. glue attributes from child associations. Compare:

    ...
    :tag
      :only
        .label
      +tagger
        :only
          .name
    end
    # Out:  {'tag' => {'label' => 'Happy Christmas!', 'tagger' => {'name' => 'Mr Lawrence"}}

Generated json fragment looks like too comprehensive. Let us rewrite this fragment using gluing feature:

    ...
    :tag
      :only
        .label
      <tagger
        :only
          .name => tagger_name
    end
    # Out:  {'tag' => {'label' => 'Happy Christmas!', 'tagger_name' => 'Mr Lawrence"}}

Of course it can be handled via additional model methods, but latter is mere artifical solution. We are going to DRY, aren't we?

## Issues ##

Strict order of definitions required! All blocks are optional.

1. :only or :except
2. :methods
3. :code blocks
4. +asscociations
5. &lt;gluening

### Benchmarks ###

    

                        user        system      total       real
    to_json             7.280000    0.440000    7.720000    (  7.811976)
    jazz                25.920000   1.840000    27.760000   ( 28.229717)
    jazz with preparse  17.210000   1.580000    18.790000   ( 19.122837)

At least for these tests it looks like to_json is ~2.4x faster..  
But for some reason you use Ruby instead of C, right? Despite of the fact that Tequila is not too fast today we are happy to have such instrument and are going to develop it further. And we have good plans about it...

### Plans ###

- Grammatic review
- Implement HashMapper fucntionality
- Arbitrary order of defenitions
- More tests for edge cases
- More syntax sugar
- Speedup

And.. we are always open for your feedback! :)