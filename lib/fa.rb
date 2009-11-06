module FiniteAutomata
  def nfa_to_dfa(nfa)
    label_state = 1
    dfa = {}
    initial_state = e_closure(nfa[:initial], nfa[:transitions])
    accept_states = []
    unmarked_states = [initial_state]
    marked_states = []
    vocab = { initial_state => 0 }
    while not unmarked_states.empty?
      state = unmarked_states.reverse!.pop
      marked_states << state
      nfa[:symbols].each do |sym|
        next_state = move_dfa(state, sym, nfa[:transitions])
        next if next_state.empty? # if there is no move to a state discart
        dfa[state] ||= []
        dfa[state] << [sym, next_state]
        next if marked_states.include? next_state
        unless unmarked_states.include? next_state
          accept_states << next_state unless (nfa[:final] & next_state).empty?
          unmarked_states << next_state
          vocab[next_state] = label_state
          label_state = label_state + 1
        end
      end
    end
    {
      :symbols => nfa[:symbols],
      :initial => vocab[initial_state],
      :final => accept_states.map { |s| vocab[s] }.sort, 
      :states => marked_states.map { |s| vocab[s] }.sort,
      :transitions => translate_dfa(dfa, vocab)
    }
  end
  
  def minimize_dfa(dfa)
    partitions = initial_partition(dfa)
    p "initial: #{partitions.inspect}"
    while true
      new_partitions = refine_partitions(partitions, dfa)
      p "new: #{new_partitions.inspect}"
      break if new_partitions.eql? partitions
      partitions = new_partitions
    end
    label_state = 0
    vocab = {}
    transitions = {}
    states = []
    partitions.sort.each do |state|
      vocab[state] = label_state
      states << label_state
      label_state = label_state + 1
      transitions[state] = []
      dfa[:symbols].each do |sym|
        state.each do |s|
          next if dfa[:transitions][s].nil?
          input, to = dfa[:transitions][s].select { |t| t[0].eql?(sym) }.first
          next if to.nil? # discart transitions to nowher
          to = partitions.select { |p| p.include? to }.first
          unless transitions[state].include? [sym, to]
            transitions[state] << [sym, to]
          end
        end
      end
    end
    translated_transitions = {}
    transitions.each do |k,v|
      translated_transitions[vocab[k]] = []
      v.each do |t|
        sym, to = t
        translated_transitions[vocab[k]] << [sym, vocab[to]]
      end
    end
    {
      :states => states,
      :symbols => dfa[:symbols],
      :initial => vocab[partitions.select { |p| p.include? dfa[:initial] }.first],
      :final => partitions.select { |p| not (p & dfa[:final]).empty? }.map { |p| vocab[p] }.sort,
      :transitions => translated_transitions
    }
  end
  
  private

  def e_closure(state, transitions)
    closure = [state]
    transitions[state].each do |t|
      input, to = t
      next unless input.nil?
      closure = closure + e_closure(to, transitions)
    end
    closure.uniq.sort
  end
  
  def e_closure_set(states, transitions)
    closure = []
    states.each do |s|
      closure = closure + e_closure(s, transitions)
    end
    closure
  end
  
  def move(states, symbol, transitions)
    closure = []
    states.each do |s|
      transitions[s].each do |t|
        input, to = t
        closure << to if input.eql?(symbol)
      end
    end
    closure.uniq.sort
  end
  
  def move_dfa(states, symbol, transitions)
    e_closure_set(move(states, symbol, transitions), transitions)
  end
  
  def translate_dfa(dfa, vocab)
    translated_dfa = {}
    dfa.each do |k, v|
      translated_dfa[vocab[k]] ||= []
      v.each do |transition|
        symbol, state = transition
        translated_dfa[vocab[k]] << [symbol, vocab[state]]
      end
    end
    translated_dfa
  end
  

  def initial_partition(dfa)
    non_final_partition = dfa[:states] - dfa[:final]
    final_partition = dfa[:final]
    [non_final_partition, final_partition]
  end
  
  def refine_partition(partition, symbol, transitions, partitions)
    return [partition] unless partition.size > 1
    groups = {}
    partition.each do |state|
      next unless transitions.has_key?(state)
      transition = transitions[state].select { |t| t[0].eql? symbol }.first
      next if transition.nil? # discart if doesnt have transition
      input, to = transition
      part = partitions.select { |p| p.include? input }.first
      groups[part] ||= []
      groups[part] << state
    end
    parts = groups.values
    rest = partition - parts.flatten
    parts << rest unless rest.empty?
    parts.compact
  end
  
  def refine_partitions(partitions, dfa)
    new_partitions = partitions
    partitions.each do |part|
      next unless part.size > 1
      dfa[:symbols].each do |sym|
        refined_partition = refine_partition(part, sym, dfa[:transitions], partitions)
        if refined_partition.size > 1
          new_partitions = new_partitions - [part] + refined_partition
          break
        end
      end
    end
    new_partitions
  end
end
