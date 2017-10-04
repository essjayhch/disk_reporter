#!/bin/env ruby
require 'json'
module Sas2ircu
class Card
  attr_accessor :id, :backplanes, :drives_by_serial, :drives_by_wnn

  CARD_REGEX = /\s{3}Enclosure#\s+:\s(\d+)\s{3}Logical ID\s+:\s([0-9a-f]+:[0-9a-f]+)\s{3}Numslots\s+:\s(\d+)\s{3}StartSlot\s+:\s(\d+)/.freeze

  BACKPLANE_REGEX = /Device is a Hard disk\s{3}Enclosure #\s+:\s(\d+)\s{3}Slot #\s+:\s(\d+)\s{3}SAS Address\s+:\s([a-f0-9\-]+)\s{3}State\s+:\s(.+)\s{3}Size \(in MB\)\/\(in sectors\)\s+:\s([0-9]+)\/([0-9]+)\s{3}Manufacturer\s+:\s(.+)\s{3}Model Number\s+:\s(.+)\s{3}Firmware Revision\s+:\s(.+)\s{3}Serial No\s+:\s(.+)\s{3}GUID\s+:\s([0-9a-f]+)\s+Protocol\s+:\s(.+)\s{3}Drive Type\s+:\s(.+)/.freeze

  def initialize(id)
    self.id = id
    self.backplanes = {}
    self.drives_by_serial = {}
    self.drives_by_wnn = {}
    populate_backplanes
  end

  def to_h
    bs = {}
    backplanes.each do |_k,b|
      bs[b.enclosure] = b.to_h
    end
    { backplanes: bs }
  end

  protected

  def sas2ircu_lines
    @lines ||= `sas2ircu #{id} display`
  end

  def populate_backplanes
    sas2ircu_lines.scan(CARD_REGEX).each do |bp|
      self.backplanes[bp[0].to_i] = Backplane.new self, bp[0].to_i, bp[1], bp[2].to_i, bp[3].to_i
    end
    populate_slots
  end

  def populate_slots
    sas2ircu_lines.scan(BACKPLANE_REGEX).each do |d|
      b = @backplanes[d[0].to_i]
      disk = Disk.new b, d
      b.slots[d[1].to_i] = disk
      self.drives_by_serial[d[9]] = disk
      self.drives_by_wnn[d[10]] = disk
    end
  end
end

class Backplane
   attr_accessor :card, :enclosure, :logical_id, :num_slots, :start_slot, :slots
   def initialize(card = nil, enclosure = nil, logical_id = nil, num_slots = nil, start_slot = nil)
     self.card = card
     self.enclosure = enclosure,
     self.logical_id = logical_id
     self.num_slots = num_slots
     self.start_slot = start_slot
     self.slots = {}
   end

   def expand_slots
     (start_slot..start_slot+num_slots-1).each do |slot_number|
       self.slots[slot_number] = Disk.new(self) unless slots[slot_number]
     end
     self
   end
  
   def to_h
     ss = {}
     slots.each do |_k,s|
       ss[s.slot] = s.to_h
     end
     { enclosure: enclosure, logical_id: logical_id, num_slots: num_slots, start_slot: start_slot, slots: ss }
   end 
end

class Disk
  attr_accessor :backplane
  def initialize(backplane, disk_array = nil)
    self.backplane = backplane
    @array = disk_array
  end

  def empty?
    @array.nil?
  end

  def slot
    @array[1]
  end

  def sas_address
    @array[2]
  end

  def state
    @array[3]
  end

  def size_mb
    @array[4]
  end

  def size_sectors
    @array[5]
  end
  
  def manufacturer
    @array[6]
  end
 
  def model_number
    @array[7]
  end

  def firmware_revision
    @array[8]
  end

  def serial_no
    @array[9]
  end

  def guid
    @array[10]
  end 

  def protocol
    @array[11]
  end

  def drive_type
    @array[12]
  end

  def to_h
    {
      slot: slot, state: state, size_mb: size_mb, size_sectors: size_sectors,
      sas_address: sas_address, manufacturer: manufacturer, 
      model_number: model_number, firmware_revision: firmware_revision,
      serial_no: serial_no, guid: guid, protocol: protocol, drive_type: drive_type
    }
  end
end

class Parser

  attr_accessor :cards

  def initialize
    self.cards = {}
    populate
  end

  def number_of_cards
    @no_cards ||= `sas2ircu list | grep Index| wc -l`
    @no_cards = @no_cards.delete("\n").to_i
  end
  
  def populate
    (0..(number_of_cards - 1)).each do |card_id|
      self.cards[card_id] = Card.new(card_id)
    end
  end

  def to_h
    cr = {} 
    cards.each do |_k,c|
      cr[c.id] = c.to_h
    end
    { cards: cr }
  end
end

puts JSON.generate Parser.new.to_h if $0 == __FILE__
end
