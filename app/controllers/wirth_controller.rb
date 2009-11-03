require 'mstwn'

class WirthController < ApplicationController
  include Compiler
  
  NONTERMINAL = /\b[A-Z][a-zA-Z]*\b/
  TERMINAL = /".+"/
  RULES = /.*\./
  RULE = /(?:(.+)\s+=)?\s+(.+\.)/
  
	def index
		@wirth_notation = params[:wirth_notation]
		return if @wirth_notation.nil?
		
		@converted = []
		@automatas = {}
		
    @wirth_notation.scan(RULES).each do |r|
      name, decl = RULE.match(r).captures
      s = Wirth.new(decl)
      s.execute
      
      stated_rule = s.output.gsub(/\b(\d+)\b/, "<span>\\1</span>").gsub(/\b([A-Z][a-zA-Z]*)\b/, "<b>\\1</b>").gsub(/("[^\s]+")/, "<i>\\1</i>")
      @converted << { :name => name, :stated => stated_rule }
      @automatas[name] = fa_to_s(s.dfa)
    end
    p @automatas
	end
	
	def reverse_rename_nonterminals(str)
	  str.scan(/[A-Z]/).uniq.each do |nt|
	    str.gsub!(/\b#{nt}\b/, @dictionary.index(nt))
    end
    str
  end
	
	def rename_nonterminals
	  ch = 65 # 'A'
    @dictionary = {}
    @wirth_notation.scan(NONTERMINAL).uniq.each do |nt|
      @dictionary[ch.chr] = nt
      @wirth_notation.gsub!(/\b#{nt}\b/, ch.chr)
      ch = ch + 1
    end
  end
end
