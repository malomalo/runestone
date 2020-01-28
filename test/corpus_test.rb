require 'test_helper'

class CorpusTest < ActiveSupport::TestCase
  
  test 'similar_words' do
    Address.create(name: 'Address name broccolini')
    
    assert_equal(
      {},
      Runestone::Corpus.similar_words('nam')
    )
    
    assert_equal(
      {'addresz' => ['address']},
      Runestone::Corpus.similar_words('addresz')
    )
    
    assert_equal(
      {'brockolinl' => ['broccolini']},
      Runestone::Corpus.similar_words('brockolinl')
    )

    assert_equal(
      {
        'addresz' => ['address'],
        'brockolinl' => ['broccolini']
      },
      Runestone::Corpus.similar_words('nam', 'addresz', 'brockolinl')
    )
  end
  
  test 'adding words to corpus downcases them' do
    Runestone::Corpus.add('Allée')
    assert_equal(
      {
        "Allee" => ["allée"]
      },
      Runestone::Corpus.similar_words('Allee')
    )
  end
  
end
