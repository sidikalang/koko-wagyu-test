class Vpc
  attr_accessor :vpc_name, :vpc_id, :vpc_subnets, :vpc_security_groups

  def initialize(options)
    @vpc_name            = options[:vpc_name]
    @vpc_id              = get_vpc_id(@vpc_name)
    @vpc_subnets         = get_vpc_subnets(@vpc_id) unless @vpc_id.empty?
    @vpc_security_groups = get_vpc_security_groups(@vpc_id) unless @vpc_id.empty?
  end

  def get_vpc_id(vpc_name)
    cmd = "aws ec2 describe-vpcs"

    vpcs_raw = nil
    vpc_id = ""

    Open3.popen3(cmd) { |stdin, stdout, stderr, wait_thr| vpcs_raw = stdout.read }
    vpcs_raw = JSON.parse(vpcs_raw)

    vpcs_raw["Vpcs"].each do |vpc|
      unless vpc["Tags"].nil?
        vpc["Tags"].each { |tag| vpc_id = vpc["VpcId"] if tag["Key"] == "Name" and tag["Value"] == vpc_name }
      end
    end

    vpc_id
  end

  def get_vpc_subnets(vpc_id)
    cmd = "aws ec2 describe-subnets --filters \"Name=vpc-id,Values=#{vpc_id}\""

    subnets_raw = nil
    subnets_clean = {}

    Open3.popen3(cmd) { |stdin, stdout, stderr, wait_thr| subnets_raw = stdout.read }
    subnets_raw = JSON.parse(subnets_raw)

    subnets_raw["Subnets"].each do |subnet|
      unless subnet["Tags"].nil?
        subnet["Tags"].each { |tag|
          subnets_clean[tag["Value"]] = subnet["AvailableIpAddressCount"] if tag["Key"] == "Name" and tag["Value"].include? "private"
        }
      end
    end

    subnets_clean.sort_by { |key, value| value }.reverse
  end

  def get_vpc_security_groups(vpc_id)
    cmd = "aws ec2 describe-security-groups --filters \"Name=vpc-id,Values=#{vpc_id}\""

    security_groups_raw = nil
    security_groups_clean = []

    Open3.popen3(cmd) { |stdin, stdout, stderr, wait_thr| security_groups_raw = stdout.read }
    security_groups_raw = JSON.parse(security_groups_raw)

    security_groups_raw["SecurityGroups"].each do |security_group|
      security_groups_clean << security_group["GroupName"] if security_group["GroupName"].include? "ssh" or security_group["GroupName"].include? "vpn"
    end

    security_groups_clean
  end

end
