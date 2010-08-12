# -*- encoding: utf-8 -*-
require 'cgi'

module ActiveMerchant
  module Shipping
    
    class CanadaPost < Carrier
      
      class CanadaPostRateResponse < RateResponse
        
        attr_reader :boxes, :postal_outlets
        
        def initialize(success, message, params = {}, options = {})
          @rates = options[:rates]
          @boxes = options[:boxes]
          @postal_outlets = options[:postal_outlets]
          super
        end
        
      end
      
      # need to store these because responses do not contain origin and destination that is sent to the server
      cattr_accessor :origin, :destination
      cattr_reader :name
      @@name = "Canada Post"
      
      Box = Struct.new(:name, :weight, :expediter_weight, :length, :width, :height, :packedItems)
      PackedItem = Struct.new(:quantity, :description)
      PostalOutlet = Struct.new(:sequence_no, :distance, :name, :business_name, :postal_address, :business_hours)
      
      DEFAULT_TURN_AROUND_TIME = 5
      ENGLISH_URL = "http://sellonline.canadapost.ca:30000"
      FRENCH_URL = "http://cybervente.canadapost.ca:30000"
      DOCTYPE = '<!DOCTYPE eparcel SYSTEM "http://sellonline.canadapost.ca/DevelopersResources/protocolV3/eParcel.dtd">'
      
      
      RESPONSE_CODES = {
       '1'     =>	"All calculation was done",
       '2'     =>	"Default shipping rates are returned due to a problem during the processing of the request.",
       '-2'    => "Missing argument when calling module",
       '-5'	   => "No Item to ship",
       '-6'	   => "Illegal Item weight",
       '-7'	   => "Illegal item dimension",
       '-12'   => "Can't open IM config file",
       '-13'   => "Can't create log files",
       '-15'   => "Invalid config file format",
       '-102'  => "Invalid socket connection",
       '-106'  => "Can't connect to server",
       '-1000' => "Unknow request type sent by client",
       '-1002' => "MAS Timed out",
       '-1004' => "Socket communication break",
       '-1005' => "Did not receive required data on socket.",
       '-2000' => "Unable to estabish socket connection with RSSS",
       '-2001' => "Merchant Id not found on server",
       '-2002' => "One or more parameter was not sent by the IM to the MAS",
       '-2003' => "Did not receive required data on socket.",
       '-2004' => "The request contains to many items to process it.",
       '-2005' => "The request received on socket is larger than the maximum allowed.",
       '-3000' => "Origin Postal Code is illegal",
       '-3001' => "Destination Postal Code/State Name/ Country  is illegal",
       '-3002' => "Parcel too large to be shipped with CPC",
       '-3003' => "Parcel too small to be shipped with CPC",
       '-3004' => "Parcel too heavy to be shipped with CPC",
       '-3005' => "Internal error code returned by the rating DLL",
       '-3006' => "The pick up time format is invalid or not defined.",
       '-4000' => "Volumetric internal error",
       '-4001' => "Volumetric time out calculation error.",
       '-4002' => "No bins provided to the volumetric engine.",
       '-4003' => "No items provided to the volumetric engine.",
       '-4004' => "Item is too large to be packed",
       '-4005' => "Number of item more than maximum allowed",
       '-5000' => "XML Parsing error",
       '-5001' => "XML Tag not found",
       '-5002' => "Node Value Number format error",
       '-5003' => "Node value is empty",
       '-5004' => "Unable to create/parse XML Document",
       '-6000' => "Unable to open the database",
       '-6001' => "Unable to read from the database",
       '-6002' => "Unable to write to the database",
       '-50000' => "Internal problem - Please contact Sell Online Help Desk"
      }
      
      def initialize(merchant_id)
        @merchant_id = merchant_id
      end
      
      def build_rate_request(origin, destination, turn_around_time, line_items = [])
        origin = Location.new(origin)
        destination = Location.new(destination)
        
        xml_request = XmlNode.new('eparcel') do |root_node|
          root_node << XmlNode.new('language', 'en')
          root_node << XmlNode.new('ratesAndServicesRequest') do |request|
            
            # Merchant Identification assigned by Canada Post
            request << XmlNode.new('merchantCPCID', @merchant_id)
            request << XmlNode.new('fromPostalCode', origin.postal_code) if origin
            request << XmlNode.new('turnAroundTime', turn_around_time) if turn_around_time
            request << XmlNode.new('itemsPrice', total_price_of(line_items))
            
            #line items
            request << build_line_items(line_items)
            
            #delivery info
            #NOTE: These tags MUST be after line items
            request << XmlNode.new('city', destination.city)
            request << XmlNode.new('provOrState', destination.province)
            request << XmlNode.new('country', destination.country)
            request << XmlNode.new('postalCode', destination.postal_code)
          end
        end
        
        DOCTYPE + xml_request.to_s
      end

      def parse_rate_response(response)
        xml = REXML::Document.new(response)
        success = response_success?(xml)
        message = response_message(xml)
        
        rate_estimates = []
        boxes = []
        if success
          xml.elements.each('eparcel/ratesAndServicesResponse/product') do |product|
            service_name = product.get_text('name').to_s
            
            delivery_date = date_for(product.get_text('deliveryDate').to_s)
            
            rate_estimates << RateEstimate.new(self.origin, self.destination, @@name, service_name,
              :total_price => product.get_text('rate').to_s,
              :delivery_date => delivery_date
            )
          end
          
          boxes = xml.elements.collect('eparcel/ratesAndServicesResponse/packing/box') do |box|
            b = Box.new
            b.packedItems = []
            b.name = box.get_text('name').to_s
            b.weight = box.get_text('weight').to_s.to_f
            b.expediter_weight = box.get_text('expediterWeight').to_s.to_f
            b.length = box.get_text('length').to_s.to_f
            b.width = box.get_text('width').to_s.to_f
            b.height = box.get_text('height').to_s.to_f
            b.packedItems = box.elements.collect('packedItem') do |item|
              p = PackedItem.new
              p.quantity = item.get_text('quantity').to_s.to_i
              p.description = item.get_text('description').to_s
              p
            end
            b
          end
          
          postal_outlets = xml.elements.collect('eparcel/ratesAndServicesResponse/nearestPostalOutlet') do |outlet|
            postal_outlet = PostalOutlet.new
            postal_outlet.sequence_no    = outlet.get_text('postalOutletSequenceNo').to_s
            postal_outlet.distance       = outlet.get_text('distance').to_s
            postal_outlet.name           = outlet.get_text('outletName').to_s
            postal_outlet.business_name  = outlet.get_text('businessName').to_s
            
            postal_outlet.postal_address = Location.new({
              :address1     => outlet.get_text('postalAddress/addressLine').to_s,
              :postal_code  => outlet.get_text('postalAddress/postal_code').to_s,
              :city         => outlet.get_text('postalAddress/municipality').to_s,
              :province     => outlet.get_text('postalAddress/province').to_s,
              :country      => 'Canada',
              :phone_number => outlet.get_text('phoneNumber').to_s
            })
          
            postal_outlet.business_hours = outlet.elements.collect('businessHours') do |hour|
              { :day_of_week => hour.get_text('dayOfWeek').to_s, :time => hour.get_text('time').to_s }
            end
            
            postal_outlet
          end
        end
        
        CanadaPostRateResponse.new(success, message, Hash.from_xml(response), :rates => rate_estimates, :xml => response, :boxes => boxes, :postal_outlets => postal_outlets)
      end
      
      def valid_credentials?
        location = self.class.default_location
        find_rates(location, location, DEFAULT_TURN_AROUND_TIME)
      rescue ActiveMerchant::Shipping::ResponseError
        false
      else
        true
      end
      
      def find_rates(origin, destination, turn_around_time, line_items = [], french = false)
        rate_request = build_rate_request(origin, destination, turn_around_time, line_items)
        commit(rate_request)
      end
      
      def self.default_location
        {
          :country => 'CA',
          :province => 'ON',
          :city => 'Ottawa',
          :address1 => '61A York St',
          :postal_code => 'K1N5T2'
        }
      end

      protected
      
      def commit(request, french = false)
        response = parse_rate_response( ssl_post(french ? FRENCH_URL : ENGLISH_URL, request) )
      end
      
      def date_for(string)
        return if !string
        return Time.parse(string)
      end

      def response_success?(xml)
        value = xml.get_text('eparcel/ratesAndServicesResponse/statusCode').to_s
        value == '1' || value == '2'
      end
      
      def response_message(xml)
        xml.get_text('eparcel/ratesAndServicesResponse/statusMessage').to_s
      end
      
      # <!-- List of items in the shopping    -->
      # <!-- cart                             -->
      # <!-- Each item is defined by :        -->
      # <!--   - quantity    (mandatory)      -->
      # <!--   - size        (mandatory)      -->
      # <!--   - weight      (mandatory)      -->
      # <!--   - description (mandatory)      -->
      # <!--   - ready to ship (optional)     -->
      
      def build_line_items(line_items)
        xml_line_items = XmlNode.new('lineItems') do |line_items_node|
          
          line_items.each do |line_item|
            
            line_items_node << XmlNode.new('item') do |item|
              item << XmlNode.new('quantity', line_item[:quantity])
              item << XmlNode.new('weight', line_item[:weight])
              item << XmlNode.new('length', line_item[:length])
              item << XmlNode.new('width', line_item[:width])
              item << XmlNode.new('height', line_item[:height])
              item << XmlNode.new('description', line_item[:description])
              item << XmlNode.new('readyToShip', line_item[:ready_to_ship] ? true : nil)
              
              # By setting the 'readyToShip' tag to true, Sell Online will not pack this item in the boxes defined in the merchant profile.
            end
          end
        end
        
        xml_line_items
      end
      
      def total_price_of(line_items)
        sum = 0
        line_items.each {|l| sum += l[:price] }
        sum
      end
    end
  end
end