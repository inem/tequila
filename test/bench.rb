require 'benchmark'
require 'test/test_helper'

module TequilaBenchmark
  def TequilaBenchmark.run(count = 500)
    humans = Human.all
    src = <<END
-humans
  :except
    .id
  +pets
    :only
      .id
    +toys
END
    Benchmark.bm(18) do |x|
      x.report('to_json')            { (1..count).each { json = humans.to_json(:except => :id, :include => { :pets => { :include => :toys, :only => :id }}) } }
      x.report('jazz')               { (1..count).each { json = TequilaParser.new.parse(TequilaPreprocessor.run(src)).eval(binding).build_hash.to_json } }
      x.report('jazz with preparse') {
        tree = TequilaParser.new.parse(TequilaPreprocessor.run(src))
        (1..count).each { json = tree.eval(binding).build_hash.to_json }
      }
    end
  end
end
