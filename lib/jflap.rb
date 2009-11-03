module JFLAP
  def generate_jflap_fa_file(filename, fa)
    f = File.new(filename, 'w')
    counter = 0
    xml = Builder::XmlMarkup.new(:target => f, :indent => 2)
    xml.instruct!
    xml.structure do
    xml.type "fa"
      fa[:states].each do |s|
        xml.state :id => s, :name => "q#{s}" do
          xml.initial if fa[:initial] == s
          xml.final if fa[:final].include?(s)
        end
        counter = counter + 1
      end
      fa[:transitions].each do |k,v|
        from = k
        v.each do |t|
          read, to = t
          xml.transition do
            xml.from from
            xml.to to
            xml.read read
          end
        end
      end
    end
    f.close
  end

  def generate_jflap_fa_file2(filename, fa)
    f = File.new(filename, 'w')
    counter = 0
    xml = Builder::XmlMarkup.new(:target => f, :indent => 2)
    xml.instruct!
    xml.structure do
    xml.type "fa"
      fa[:states].each do |s|
        xml.state :id => s, :name => "q#{s}" do
          xml.initial if fa[:initial] == s
          xml.final if fa[:final].include?(s)
        end
        counter = counter + 1
      end
      fa[:transitions].each do |t|
        from, read, to = t
        xml.transition do
          xml.from from
          xml.to to
          xml.read read
        end
      end
    end
    f.close
  end
end