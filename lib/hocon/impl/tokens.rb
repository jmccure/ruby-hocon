require 'hocon/impl'
require 'hocon/impl/token'
require 'hocon/impl/token_type'
require 'hocon/impl/config_number'
require 'hocon/impl/config_string'
require 'hocon/impl/config_null'
require 'hocon/impl/config_boolean'
require 'hocon/config_error'

# FIXME the way the subclasses of Token are private with static isFoo and accessors is kind of ridiculous.
class Hocon::Impl::Tokens
  Token = Hocon::Impl::Token
  TokenType = Hocon::Impl::TokenType
  ConfigNumber = Hocon::Impl::ConfigNumber
  ConfigInt = Hocon::Impl::ConfigInt
  ConfigFloat = Hocon::Impl::ConfigFloat
  ConfigString = Hocon::Impl::ConfigString
  ConfigNull = Hocon::Impl::ConfigNull
  ConfigBoolean = Hocon::Impl::ConfigBoolean

  START = Token.new_without_origin(TokenType::START, "start of file")
  EOF = Token.new_without_origin(TokenType::EOF, "end of file")
  COMMA = Token.new_without_origin(TokenType::COMMA, "','")
  EQUALS = Token.new_without_origin(TokenType::EQUALS, "'='")
  COLON = Token.new_without_origin(TokenType::COLON, "':'")
  OPEN_CURLY = Token.new_without_origin(TokenType::OPEN_CURLY, "'{'")
  CLOSE_CURLY = Token.new_without_origin(TokenType::CLOSE_CURLY, "'}'")
  OPEN_SQUARE = Token.new_without_origin(TokenType::OPEN_SQUARE, "'['")
  CLOSE_SQUARE = Token.new_without_origin(TokenType::CLOSE_SQUARE, "']'")
  PLUS_EQUALS = Token.new_without_origin(TokenType::PLUS_EQUALS, "'+='")

  class Comment < Token
    def initialize(origin, text)
      super(TokenType::COMMENT, origin)
      @text = text
    end
    attr_reader :text

    def ==(other)
      super(other) && other.text == @text
    end

    def hash
      hashcode = 41 * (41 + super)
      hashcode = 41 * (hashcode + @text.hash)

      hashcode
    end
  end

  # This is not a Value, because it requires special processing
  class Substitution < Token
    def initialize(origin, optional, expression)
      super(TokenType::SUBSTITUTION, origin)
      @optional = optional
      @value = expression
    end

    attr_reader :value

    def ==(other)
      super(other) && other.value == @value
    end

    def hash
      41 * (41 + super + @value.hash)
    end
  end

  class UnquotedText < Token
    def initialize(origin, s)
      super(TokenType::UNQUOTED_TEXT, origin)
      @value = s
    end
    attr_reader :value

    def to_s
      "'#{value}'"
    end

    def ==(other)
      super(other) && other.value == @value
    end

    def hash
      41 * (41 + super) + value.hash
    end
  end

  class Value < Token
    def initialize(value)
      super(TokenType::VALUE, value.origin)
      @value = value
    end

    attr_reader :value

    def to_s
      "'#{value.unwrapped}' (#{Hocon::ConfigValueType.name(value.value_type)})"
    end

    def ==(other)
      super(other) && other.value == @value
    end

    def hash
      41 * (41 + super) + value.hash
    end
  end

  class Line < Token
    def initialize(origin)
      super(TokenType::NEWLINE, origin)
    end

    def ==(other)
      super(other) && other.line_number == line_number
    end

    def hash
      41 * (41 + super) + line_number
    end
  end

  class Problem < Token
    def initialize(origin, what, message, suggest_quotes, cause)
      super(TokenType::PROBLEM, origin)
      @what = what
      @message = message
      @suggest_quotes = suggest_quotes
      @cause = cause
    end

    def what
      @what
    end

    def message
      @message
    end

    def suggest_quotes
      @suggest_quotes
    end

    def cause
      @cause
    end

    def ==(other)
      super(other) && other.what == @what &&
          other.message == @message &&
          other.suggest_quotes == @suggest_quotes &&
          Hocon::Impl::ConfigImplUtil.equals_handling_nil?(other.cause, @cause)
    end

    def hash
      hashcode = 41 * (41 + super)
      hashcode = 41 * (hashcode + @what.hash)
      hashcode = 41 * (hashcode + @message.hash)
      hashcode = 41 * (hashcode + @suggest_quotes.hash)
      unless @cause.nil?
        hashcode = 41 * (hashcode + @cause.hash)
      end

      hashcode
    end
  end

  def self.get_problem_message(token)
    if token.is_a?(Problem)
      token.message
    else
      raise Hocon::ConfigError::ConfigBugOrBrokenError.new("tried to get problem message from #{token}", nil)
    end
  end

  def self.get_problem_suggest_quotes(token)
    if token.is_a?(Problem)
      token.suggest_quotes
    else
      raise Hocon::ConfigError::ConfigBugOrBrokenError.new("tried to get problem suggest_quotes from #{token}", nil)
    end
  end

  def self.get_problem_cause(token)
    if token.is_a?(Problem)
      token.cause
    else
      raise Hocon::ConfigError::ConfigBugOrBrokenError.new("tried to get problem cause from #{token}", nil)
    end
  end

  def self.new_line(origin)
    Line.new(origin)
  end

  def self.new_problem(origin, what, message, suggest_quotes, cause)
    Problem.new(origin, what, message, suggest_quotes, cause)
  end

  def self.new_comment(origin, text)
    Comment.new(origin, text)
  end

  def self.new_unquoted_text(origin, s)
    UnquotedText.new(origin, s)
  end

  def self.new_value(value)
    Value.new(value)
  end

  def self.new_string(origin, value)
    new_value(ConfigString.new(origin, value))
  end

  def self.new_int(origin, value, original_text)
    new_value(ConfigNumber.new_number(origin, value, original_text))
  end

  def self.new_float(origin, value, original_text)
    new_value(ConfigNumber.new_number(origin, value, original_text))
  end

  def self.new_long(origin, value, original_text)
    new_value(ConfigNumber.new_number(origin, value, original_text))
  end

  def self.new_null(origin)
    new_value(ConfigNull.new(origin))
  end

  def self.new_boolean(origin, value)
    new_value(ConfigBoolean.new(origin, value))
  end

  def self.new_substitution(origin, optional, expression)
    Substitution.new(origin, optional, expression)
  end

  def self.comment?(t)
    t.is_a?(Comment)
  end

  def self.comment_text(token)
    if comment?(token)
      token.text
    else
      raise ConfigBugError, "tried to get comment text from #{token}"
    end
  end

  def self.substitution?(t)
    t.is_a?(Substitution)
  end

  def self.unquoted_text?(token)
    token.is_a?(UnquotedText)
  end

  def self.unquoted_text(token)
    if unquoted_text?(token)
      token.value
    else
      raise ConfigBugError, "tried to get unquoted text from #{token}"
    end
  end

  def self.value?(token)
    token.is_a?(Value)
  end

  def self.value(token)
    if token.is_a?(Value)
      token.value
    else
      raise ConfigBugError, "tried to get value of non-value token #{token}"
    end
  end

  def self.value_with_type?(t, value_type)
    value?(t) && (value(t).value_type == value_type)
  end

  def self.newline?(t)
    t.is_a?(Line)
  end

  def self.problem?(t)
    t.is_a?(Problem)
  end
end
