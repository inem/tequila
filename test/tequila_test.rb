require 'test/unit'
require 'test_helper'
require 'json'

require File.dirname(__FILE__) + '/../lib/preprocessor'

class TestTequila < Test::Unit::TestCase
  DIR = "data/"
  def run_test(jazz, json, init = 'humans = Human.all :order => "name"', explicit = false)
    parser = TequilaParser.new
    eval(init)
    jazz = TequilaPreprocessor.run(jazz)
    parsed_template = parser.parse(jazz)
    evaluated_template = parsed_template.eval(binding)
    json2 = evaluated_template.build_hash
    return json2 if explicit
    assert_json_equal(json, json2.to_json, name)
  end

  def assert_json_equal(expected, actual, message=nil)
    expected = JSON.parse(expected)
    actual = JSON.parse(actual)
    full_message = build_message(message, "<?> expected but was\n<?>.\n", expected.inspect, actual.inspect)
    assert_block(full_message) { expected == actual }
  end

  def test_big_request
    jazz = <<END
-eugene
  :except
    .id
  :code => where
    'I am from ' + address
  +pets
    :except
      .id
      .human_id
      .pet_type_id
    :methods
      .which('wet', 'cold')
    +toys
      :only
        .label
    <pet_type
      :only
        .class_name => pet_type
END
    json = '{ "eugene" :
      { "name" : "Eugene",
        "address" : "district3",
        "where" : "I am from district3",
        "pets" :
        [ {"pet" :
          { "name" : "Poiyo",
            "which": "Poiyo is wet and cold",
            "toys" :
            [ { "toy" : { "label" : "LHC" } },
              { "toy" : { "label" : "Humanity" } } ],
            "pet_type" : "fish"}}
        ]}}'
    json2 = run_test jazz, json, 'eugene = Human.first', true
    eugene = json2['eugene']
    pets = eugene['pets']
    pet = pets[0]['pet']
    assert_equal 'Eugene', eugene['name']
    assert_equal 'district3', eugene['address']
    assert_equal 'I am from district3', eugene['where']
    assert_equal 1, pets.size
    assert_equal 'Poiyo', pet['name']
    assert_equal 'Poiyo is wet and cold', pet['which']
    assert_equal [ { 'toy' => { 'label' => 'Humanity' } }, { 'toy' => { 'label' => 'LHC' } } ], pet['toys'].sort { |x, y|
      x['toy']['label'] <=> y['toy']['label']
    }
  end

  def test_only
    jazz = <<END
-humans
  :only
    .name
END
    json = '{ "humans" : [ { "human" : {"name":"Alex"} },{ "human" : {"name":"Eugene"} }, { "human" : {"name":"Ivan"} }, { "human" : {"name":"Oleg"} }] }'
    run_test jazz, json
  end

  def test_except
    jazz = <<END
-humans
  :except
    .address
    .id
END
  json = '{ "humans" : [ { "human" : {"name":"Alex"} },{ "human" : {"name":"Eugene"} }, { "human" : {"name":"Ivan"} }, { "human" : {"name":"Oleg"} }] }'
  run_test jazz, json
  end
  def test_methods
    jazz = <<END
-scooby
  :except
    .id
    .human_id
    .pet_type_id
  :methods
    .which
END
  json = '{ "scooby" : { "which" : "Skooby Doo is big and cheerful", "name" : "Skooby Doo"}}'
  run_test(jazz, json, 'scooby = Pet.find_by_name "Skooby Doo"')
  end
  def test_methods_with_params
    jazz = <<END
-mat
  :except
    .id
    .human_id
    .pet_type_id
  :methods
    .which('striped','reasonable')
END
    json = '{ "mat" : { "which" : "Matroskin is striped and reasonable", "name" : "Matroskin"}}'
    run_test(jazz, json, 'mat = Pet.find_by_name "Matroskin"')
  end
  def test_association
    jazz = <<END
-eugene
  :only
    .name
  +pets
    :only
      .name
END
    json = '{ "eugene" : { "name" : "Eugene", "pets" : [ { "pet" : { "name" : "Poiyo"}} ] }}'
    run_test(jazz, json, 'eugene = Human.find_by_name "Eugene"')
  end
  def test_rename
    jazz = <<END
-humans => people
  :only
    .name => login
END
    json = '{ "people" : [ { "person" : {"login":"Alex"} },{ "person" : {"login":"Eugene"} }, { "person" : {"login":"Ivan"} }, { "person" : {"login":"Oleg"} }] }'
    run_test jazz, json
  end
  def test_code
    jazz = <<END
-humans => people
  :except
    .name
    .id
    .address
  :code => hello
    "Hello, " + name + "!"
END
    json = '{ "people" : [ { "person" : {"hello":"Hello, Alex!"} }, { "person" : {"hello":"Hello, Eugene!"} }] }'
    run_test jazz, json, 'humans = Human.all :conditions => "name in (\"Eugene\", \"Alex\")", :order => "name"'
  end
  def test_inner_association
     jazz = <<END
-ivan
  :except
    .id
    .address
  +pets
    :only
      .name
    +pet_type
      :only
        .class_name => whois
END
    json = '{
      "ivan" :
        { "name" : "Ivan",
          "pets" : [
          { "pet" :
            { "name" : "Skooby Doo" ,
              "pet_type":
              { "whois" : "dog" } }  } ] } }'
    run_test jazz, json, 'ivan = Human.find_by_name "Ivan"'
  end
  def test_gluing
    jazz = <<END
-ivan
  :except
    .id
    .address
  +pets
    :only
      .name
    <pet_type
      :only
        .class_name => whois
END
    json = '{
      "ivan" :
        { "name" : "Ivan",
          "pets" : [
          { "pet" :
            { "name" : "Skooby Doo" ,
              "whois" : "dog" }  } ] } }'
    run_test jazz, json, 'ivan = Human.find_by_name "Ivan"'
  end
####  include files ####
  def test_include_file
    jazz = <<END
-human
  :only
    .name
  &test/pets
END
    jazz_for_treetop = <<END
-human
  :only
    .name
  +pets
    :only
      .id
end
end
END
    assert_equal TequilaPreprocessor.run(jazz), jazz_for_treetop
  end

  def test_label_building
    jazz =<<END
-@eugene
  :only
    .name
END
    json = %q{{"eugene" :  { "name" : "Eugene" }}}
    run_test jazz, json, '@eugene = Human.find_by_name "Eugene"'
  end

  def test_has_many_empty_associan
    jazz =<<END
-josh
  :only
    .name
  +pets
    :only
      .name
END
    @josh = Human.create({:name => 'Josh'})
    json = %q{{"josh" :  { "name" : "Josh", "pets" : [] }}}
    run_test jazz, json, 'josh = Human.find_by_name "Josh"'
    @josh.destroy
  end

  def test_nil_association
    jazz =<<END
-pet
  :only
    .name
  +human
    :only
      .name
END
    @pet = Pet.create({:name => 'Godzilla'})
    json = %q{{"pet" :  { "name" : "Godzilla"}}}
    run_test jazz, json, 'pet = Pet.find_by_name "Godzilla"'
    @pet.destroy
  end

  def test_suppress_label
    jazz = <<END
-humans~
  :only
    .name
END
    json = '{ "humans" : [ {"name":"Alex"} ,{"name":"Eugene"}, {"name":"Ivan"}, {"name":"Oleg"} ] }'
    run_test jazz, json
  end


  def test_static_values
    jazz = <<END
-obj
  :static
    name => static_field
END
    json = '{ "obj" : {"name" : "static_field"}}'
    run_test jazz, json, "obj = Object.new"
  end

end
