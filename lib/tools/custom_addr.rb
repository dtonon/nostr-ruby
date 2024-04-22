class CustomAddr

  attr_accessor :hrp # human-readable part
  attr_accessor :prog # witness program

  def initialize(addr = nil)
    @hrp, @prog = parse_addr(addr) if addr
  end

  def to_scriptpubkey
    prog.map{|p|[p].pack("C")}.join.unpack('H*').first
  end

  def scriptpubkey=(script)
    values = [script].pack('H*').unpack("C*")
    @prog = values
  end

  def addr
    spec = Bech32::Encoding::BECH32
    Bech32.encode(hrp, convert_bits(prog, 8, 5), spec)
  end

  private

  def parse_addr(addr)
    hrp, data, spec = Bech32.decode(addr)
    raise 'Invalid address.' if hrp.nil? || data[0].nil?
    # raise 'Invalid witness version' if ver > 16
    prog = convert_bits(data, 5, 8, false)
    # raise 'Invalid witness program' if prog.nil? || prog.length < 2 || prog.length > 40
    # raise 'Invalid witness program with version 0' if ver == 0 && (prog.length != 20 && prog.length != 32)
    [hrp, prog]
  end

  def convert_bits(data, from, to, padding=true)
    acc = 0
    bits = 0
    ret = []
    maxv = (1 << to) - 1
    max_acc = (1 << (from + to - 1)) - 1
    data.each do |v|
      return nil if v < 0 || (v >> from) != 0
      acc = ((acc << from) | v) & max_acc
      bits += from
      while bits >= to
        bits -= to
        ret << ((acc >> bits) & maxv)
      end
    end
    if padding
      ret << ((acc << (to - bits)) & maxv) unless bits == 0
    elsif bits >= from || ((acc << (to - bits)) & maxv) != 0
      return nil
    end
    ret
  end

end
