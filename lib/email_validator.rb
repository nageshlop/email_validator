# Based on work from http://thelucid.com/2010/01/08/sexy-validation-in-edge-rails-rails-3/
class EmailValidator < ActiveModel::EachValidator
  # rubocop:disable Style/ClassVars
  @@default_options = {
    :allow_nil => false,
    :domain => nil,
    :require_fqdn => nil,
    :mode => :loose
  }
  # rubocop:enable Style/ClassVars

  class << self
    def default_options
      @@default_options
    end

    def valid?(value, options = {})
      options = parse_options(options)
      return true if value.nil? && options[:allow_nil] == true
      return false if value.nil?
      !!(value =~ regexp(options))
    end

    def invalid?(value, options = {})
      !valid?(value, options)
    end

    # Refs:
    #  https://tools.ietf.org/html/rfc2822 : 3.2. Lexical Tokens, 3.4.1. Addr-spec specification
    #  https://tools.ietf.org/html/rfc5321 : 4.1.2.  Command Argument Syntax
    def regexp(options = {})
      options = parse_options(options)
      if options[:mode] == :loose
        return /\A[^\s]+@[^\s]+\z/ if options[:domain].nil?
        return /\A[^\s]+@#{domain_pattern(options)}\z/
      end
      /\A(?>#{local_part_pattern})@#{domain_pattern(options)}\z/i
    end

    protected

    def alpha
      '[[:alpha:]]'
    end

    def alnum
      '[[:alnum:]]'
    end

    def alnumhy
      "(?:#{alnum}|-)"
    end

    def ipv4
      '\d{1,3}(?:\.\d{1,3}){3}'
    end

    def ipv6
      # only supporting full IPv6 addresses right now
      'IPv6:[[:xdigit:]]{1,4}(?::[[:xdigit:]]{1,4}){7}'
    end

    def address_literal
      "\\[(?:#{ipv4}|#{ipv6})\\]"
    end

    def label_pattern
      "#{alpha}(?:#{alnumhy}{,62}#{alnum})?"
    end

    def atom_char
      # The `atext` spec
      # We are looking at this without whitespace; no whitespace support here
      "[-#{alpha}#{alnum}+_!\"'#$%^&*{}/=?`|~]"
    end

    def local_part_pattern
      # the `dot-atom-text` spec, but with a 64 character limit
      "#{atom_char}(?:\\.?#{atom_char}){,63}"
    end

    def domain_pattern(options)
      return options[:domain].sub(/\./, '\.') if options[:domain].present?
      return "(?:#{label_pattern}\\.)+#{label_pattern}" if options[:require_fqdn]
      "(?:#{address_literal}|(?:#{label_pattern}\\.)*#{label_pattern})"
    end

    private

    def parse_options(options)
      # `:moderate` mode enables `:require_fqdn`, unless it is already explicitly disabled
      options[:require_fqdn] = true if options[:require_fqdn].nil? && options[:mode] == :moderate
      default_options.merge(options)
    end
  end

  def validate_each(record, attribute, value)
    options = @@default_options.merge(self.options)
    record.errors.add(attribute, options[:message] || :invalid) unless self.class.valid?(value, options)
  end
end
