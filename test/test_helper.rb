# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../lib', __FILE__)

require 'simplecov'
SimpleCov.start do
  add_filter %r{^/test/}
  # add_group 'lib', 'sunstone/lib'
  # add_group 'ext', 'sunstone/ext'
end

require "minitest/autorun"
require 'minitest/unit'
require 'minitest/reporters'
require 'faker'
require 'byebug'

require 'active_record'
require 'active_job'
require 'active_job/test_helper'
ActiveJob::Base.queue_adapter = :test
require 'runestone'

# Setup the test db
ActiveSupport.test_order = :random
require File.expand_path('../database', __FILE__)

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

$debugging = false

# File 'lib/active_support/testing/declarative.rb', somewhere in rails....
class ActiveSupport::TestCase
  
  include ActiveJob::TestHelper
  
  # File 'lib/active_support/testing/declarative.rb'
  def self.test(name, &block)
    test_name = "test_#{name.gsub(/\s+/, '_')}".to_sym
    defined = method_defined? test_name
    raise "#{test_name} is already defined in #{self}" if defined
    if block_given?
      define_method(test_name, &block)
    else
      define_method(test_name) do
        skip "No implementation provided for #{name}"
      end
    end
  end

  def teardown
    super
    Runestone.synonyms.clear
    Runestone::Model.connection.execute('DELETE FROM runestone_corpus')
    ActiveRecord::Base.subclasses.reject{|k| k.name.start_with?('ActiveRecord') }.each(&:delete_all)
  end
  
  def debug
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    $debugging = true
    yield
  ensure
    ActiveRecord::Base.logger = nil
    $debugging = false
  end

  def capture_sql
    # ActiveRecord::Base.connection.materialize_transactions
    SQLLogger.clear_log
    yield
    SQLLogger.log_all.dup
  end

  def assert_sql(*patterns_to_match)
    if patterns_to_match.all? { |s| s.is_a?(String) }
      assert_equal(*patterns_to_match.take(2).map { |sql| sql.gsub(/( +|\n\s*|\s+)/, ' ').strip })
    else
      begin
        ret_value = nil
        capture_sql { ret_value = yield }
        ret_value
      ensure
        failed_patterns = []
        patterns_to_match.each do |pattern|
          failed_patterns << pattern unless SQLLogger.log_all.any?{ |sql| pattern === sql }
        end
        assert failed_patterns.empty?, "Query pattern(s) #{failed_patterns.map(&:inspect).join(', ')} not found.#{SQLLogger.log.size == 0 ? '' : "\nQueries:\n#{SQLLogger.log.join("\n")}"}"
      end
    end
  end

  def assert_no_sql(*patterns_to_match)
    if patterns_to_match.all? { |s| s.is_a?(String) }
      assert_not_equal(*patterns_to_match.take(2).map { |sql| sql.gsub(/( +|\n\s*|\s+)/, ' ').strip })
    else
      begin
        ret_value = nil
        capture_sql { ret_value = yield }
        ret_value
      ensure
        failed_patterns = []
        patterns_to_match.each do |pattern|
          failed_patterns << pattern unless SQLLogger.log_all.any?{ |sql| pattern === sql }
        end
        assert !failed_patterns.empty?, "Query pattern(s) #{failed_patterns.map(&:inspect).join(', ')} found.#{SQLLogger.log.size == 0 ? '' : "\nQueries:\n#{SQLLogger.log.join("\n")}"}"
      end
    end
  end
  
  def corpus
    Runestone::Model.connection.execute('SELECT word FROM runestone_corpus ORDER BY word').values.flatten
  end
  
  def assert_corpus(*words)
    assert_equal words.flatten.sort, corpus
  end
  
  def assert_corpus_has(*words)
    assert_equal 0, (words - corpus).size
  end
  
  class SQLLogger
    class << self
      attr_accessor :ignored_sql, :log, :log_all
      def clear_log; self.log = []; self.log_all = []; end
    end

    self.clear_log

    self.ignored_sql = [/^PRAGMA/i, /^SELECT currval/i, /^SELECT CAST/i, /^SELECT @@IDENTITY/i, /^SELECT @@ROWCOUNT/i, /^SAVEPOINT/i, /^ROLLBACK TO SAVEPOINT/i, /^RELEASE SAVEPOINT/i, /^SHOW max_identifier_length/i, /^BEGIN/i, /^COMMIT/i]

    # FIXME: this needs to be refactored so specific database can add their own
    # ignored SQL, or better yet, use a different notification for the queries
    # instead examining the SQL content.
    oracle_ignored     = [/^select .*nextval/i, /^SAVEPOINT/, /^ROLLBACK TO/, /^\s*select .* from all_triggers/im, /^\s*select .* from all_constraints/im, /^\s*select .* from all_tab_cols/im]
    mysql_ignored      = [/^SHOW FULL TABLES/i, /^SHOW FULL FIELDS/, /^SHOW CREATE TABLE /i, /^SHOW VARIABLES /, /^\s*SELECT (?:column_name|table_name)\b.*\bFROM information_schema\.(?:key_column_usage|tables)\b/im]
    postgresql_ignored = [/^\s*select\b.*\bfrom\b.*pg_namespace\b/im, /^\s*select tablename\b.*from pg_tables\b/im, /^\s*select\b.*\battname\b.*\bfrom\b.*\bpg_attribute\b/im, /^SHOW search_path/i]
    sqlite3_ignored =    [/^\s*SELECT name\b.*\bFROM sqlite_master/im, /^\s*SELECT sql\b.*\bFROM sqlite_master/im]

    [oracle_ignored, mysql_ignored, postgresql_ignored, sqlite3_ignored].each do |db_ignored_sql|
      ignored_sql.concat db_ignored_sql
    end

    attr_reader :ignore

    def initialize(ignore = Regexp.union(self.class.ignored_sql))
      @ignore = ignore
    end

    def call(name, start, finish, message_id, values)
      sql = values[:sql]

      # FIXME: this seems bad. we should probably have a better way to indicate
      # the query was cached
      return if 'CACHE' == values[:name]

      self.class.log_all << sql
      unless ignore =~ sql
        if $debugging
        puts caller.select { |l| l.starts_with?(File.expand_path('../../lib', __FILE__)) }
        puts "\n\n" 
        end
      end
      self.class.log << sql unless ignore =~ sql
    end
  end
  ActiveSupport::Notifications.subscribe('sql.active_record', SQLLogger.new)

  # test/unit backwards compatibility methods
  alias :assert_raise :assert_raises
  alias :assert_not_empty :refute_empty
  alias :assert_not_equal :refute_equal
  alias :assert_not_in_delta :refute_in_delta
  alias :assert_not_in_epsilon :refute_in_epsilon
  alias :assert_not_includes :refute_includes
  alias :assert_not_instance_of :refute_instance_of
  alias :assert_not_kind_of :refute_kind_of
  alias :assert_no_match :refute_match
  alias :assert_not_nil :refute_nil
  alias :assert_not_operator :refute_operator
  alias :assert_not_predicate :refute_predicate
  alias :assert_not_respond_to :refute_respond_to
  alias :assert_not_same :refute_same
  
end