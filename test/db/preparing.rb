require 'rubygems'
require 'activerecord'
require 'sqlite3'

# setup db connection

ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + 'debug.log')
ActiveRecord::Base.configurations = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.establish_connection('demo')

# setup db layout

ActiveRecord::Schema.define :version => 0 do
  create_table :humans, :force => true do |t|
    t.string :name
    t.string :address
  end

  create_table :pets, :force => true do |t|
    t.string :name
    t.integer :pet_type_id
    t.integer :human_id
  end

  create_table :pet_types, :force => true do |t|
    t.string :class_name
  end

  create_table :toys, :force => true do |t|
    t.string :label
    t.float :price
  end

  create_table :pets_toys, :force => true, :id => false do |t|
    t.integer :toy_id
    t.integer :pet_id
  end

end

# define models

class Human < ActiveRecord::Base
  set_table_name :humans
  has_many :pets
end

class Pet < ActiveRecord::Base
  has_and_belongs_to_many :toys
  belongs_to :pet_type
  belongs_to :human
  def which(first = 'big', second = 'cheerful')
    "#{name} is #{first} and #{second}"
  end
end

class PetType < ActiveRecord::Base
end

class Toy < ActiveRecord::Base
  has_and_belongs_to_many :pets

  def railsize(*strs)
    strs.join.gsub('PHP','Ruby').gsub('Django','Rails')
  end
end

# load fixtures

require 'active_record/fixtures'

Fixtures.reset_cache
fixtures_folder = File.dirname(__FILE__) + '/fixtures'
fixtures = Dir[File.join(fixtures_folder, '*.yml')].map {|f| File.basename(f, '.yml') }
Fixtures.create_fixtures(fixtures_folder, fixtures)

