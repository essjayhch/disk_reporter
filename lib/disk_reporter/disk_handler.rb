#!/bin/env ruby
require 'json'
module DiskHandler
class Disk
  attr_accessor :name, :type, :size, :model, :state, :id, :number, :version, :partitions

  def device_path
    "/dev/#{name}"
  end

  def serial_number
   number.strip
  end

  def wnn
    id.delete(' ') unless id.nil?
  end

  def initialize lsblk_line
    attrs_from_line lsblk_line
    check_smart_capability!
    check_health! if smart_capable?
    parse_smart_info if smart_capable?
    populate_partitions
  end

  def attrs_from_line lsblk_line
    %w{NAME TYPE SIZE MODEL STATE}.each do |key|
      matches = lsblk_line.match(/#{key}="([^"]*)"/)
      self.send("#{key.downcase}=", matches[1]) if matches
    end
  end

  def get_smart_info
    `smartctl -i /dev/#{name}`
  end

  # Is the device SMART capable and enabled
  #
  def smart_capable?
    @smart_available && @smart_enabled
  end

  # Check the SMART health
  #
  def check_health!
    output = `sudo smartctl -H #{device_path}`
    @smart_healthy = !output.scan(/PASSED/).empty?
    @health_output = output
  end

  # Parses SMART drive info
  #
  def parse_smart_info
     %w{Id Number Version}.each do |key|
       matches = @capability_output.match(/#{key}:\s+([^\n]*)\n/)
       self.send("#{key.downcase}=", matches[1]) if matches
     end
  end
  # Checks if disk is capable
  #
  def check_smart_capability!
    output = `sudo smartctl -i #{device_path}`
    @smart_available = !output.scan(/SMART support is: Available/).empty?
    @smart_enabled = !output.scan(/SMART support is: Enabled/).empty?
    @capability_output = output
  end

  def to_h
    { name: name, size: size, model: model, smart_available: @smart_available, smart_enabled: @smart_enabled, wnn: wnn, serial: serial_number, version: version
     }
  end

  def populate_partitions
    self.partitions = []
    `ls #{device_path}[0-9]* 2>/dev/null`.each_line do |name|
       self.partitions << Partition.new(self, name)
    end
  end
end

class Partition
  attr_accessor :disk, :name, :fs, :uuid, :uuid_sub, :type, :mounted
  BLKID_REGEX = %r[/dev/.*:\sUUID="(.{36})"\s(UUID_SUB="(.{36})"\s)*TYPE="(.*)"\s]
  def initialize(disk, name)
    self.disk = disk
    self.name = name.gsub("\n", "")
    blkid
  end

  def is_ceph?
    mounted? && mounted.match(%r{/var/lib/ceph/})
  end

  def should_have_ceph?
    true
  end

  def mounted?
    !!mounted
  end

  def fs?
    !!fs
  end

  def blkid
    response = `blkid #{name}`
    self.fs = $?.exitstatus == 0
    # puts "FS: #{fs}"
    # puts response
    if fs?
      resp = response.scan(BLKID_REGEX)
      if resp && resp[0]
        self.uuid = resp[0][0]
        self.uuid_sub = resp[0][2]
        self.type = resp[0][3]
      end
      # puts 'check if mounted'
      # puts "grep #{name} /proc/mounts"
      mtab = `grep #{name} /proc/mounts`
      self.mounted = mtab.split(' ')[1] if $?
    end
  end
end

class Parser
  attr_accessor :devices
  def initialize
    self.devices = []
    populate
  end

  def to_h
    disks = []
    devices.each do |d|
      disks << d.to_h
    end
    { disks: disks }
  end

  private

  def scan_disks
     ds = []
    `lsblk -Pbdo NAME,TYPE,SIZE,MODEL,STATE`.each_line do |line|
      ds << Disk.new(line)
    end
    ds
  end

  def populate
    scan_disks.each do |d|
      self.devices << d
    end
  end
end

puts JSON.generate Parser.new.to_h if $0 == __FILE__
end
