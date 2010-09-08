require 'test_helper'

class CanadaPostTest < Test::Unit::TestCase

  def setup
    @carrier  = CanadaPost.new(:login => 'CPC_DEMO_XML')
    @french_carrier  = CanadaPost.new(:login => 'CPC_DEMO_XML', :french => true)
    @request  = xml_fixture('canadapost/example_request')
    @response = xml_fixture('canadapost/example_response')
    @response_french = xml_fixture('canadapost/example_response_french')
    @bad_response = xml_fixture('canadapost/example_response_error')
    
    @origin      = {:address1 => "61A York St", :city => "Ottawa", :province => "ON", :country => "Canada", :postal_code => "K1N 5T2"}
    @destination = {:city => "Beverly Hills", :state => "CA", :country => "United States", :postal_code => "90210"}
    @line_items  = [Package.new(500, [2, 3, 4], :description => "a box full of stuff", :value => 25)]
  end
  
  def test_french_false
    assert !@carrier.french?
  end
  
  def test_french_true
    assert @french_carrier.french?
  end
  
  def test_parse_rate_response_french
    assert_equal @request, @french_carrier.build_rate_request(@origin, @destination, 24, @line_items)
  end
  
  def test_parse_rate_response_french
    rate_response = @french_carrier.parse_rate_response(@response_french)
    assert rate_response.is_a?(RateResponse)
    assert rate_response.success?
    
    rate_response.rate_estimates.each do |rate|
      assert_instance_of RateEstimate, rate
      assert_instance_of Time, rate.delivery_date
      assert_instance_of String, rate.service_name
      assert_instance_of Fixnum, rate.total_price
    end
    
    rate_response.boxes.each do |box|
      assert_instance_of CanadaPost::Box, box
      assert_instance_of String, box.name
      assert_instance_of Float, box.weight
      assert_instance_of Float, box.expediter_weight
      assert_instance_of Float, box.length
      assert_instance_of Float, box.height
      assert_instance_of Float, box.width

      box.packedItems.each do |p|
        assert_instance_of Fixnum, p.quantity
        assert_instance_of String, p.description
      end
    end
    
  end
  
  def test_build_rate_request
    assert_equal @request, @carrier.build_rate_request(@origin, @destination, 24, @line_items)
  end
  
  def test_parse_rate_response
    rate_response = @carrier.parse_rate_response(@response)
    assert rate_response.is_a?(RateResponse)
    assert rate_response.success?
    
    rate_response.rate_estimates.each do |rate|
      assert_instance_of RateEstimate, rate
      assert_instance_of Time, rate.delivery_date
      assert_instance_of String, rate.service_name
      assert_instance_of Fixnum, rate.total_price
    end
    
    rate_response.boxes.each do |box|
      assert_instance_of CanadaPost::Box, box
      assert_instance_of String, box.name
      assert_instance_of Float, box.weight
      assert_instance_of Float, box.expediter_weight
      assert_instance_of Float, box.length
      assert_instance_of Float, box.height
      assert_instance_of Float, box.width

      box.packedItems.each do |p|
        assert_instance_of Fixnum, p.quantity
        assert_instance_of String, p.description
      end
    end
  end
  
  def test_non_success_parse_rate_response
    assert_raise ActiveMerchant::Shipping::ResponseError do
      rate_response = @carrier.parse_rate_response(@bad_response)
      
      assert rate_response.is_a?(RateResponse)
      assert !rate_response.success?

      assert_equal [], rate_response.rate_estimates
      assert_equal [], rate_response.boxes
    end
  end
  
  def test_date_for_nil_string
    assert_nil @carrier.send(:date_for, nil)
  end
  
  def test_build_line_items
    xml_line_items = @carrier.send(:build_line_items, @line_items)
    assert_instance_of XmlNode, xml_line_items
    
    xml_string = xml_line_items.to_s
    assert_match /a box full of stuff/, xml_string
  end
  
  def test_total_price_of
    @line_items  = [Package.new(500, [2, 3, 4], :description => "a box full of stuff", :value => 25)]
    assert_equal 25, @carrier.send(:total_price_of, @line_items)
  end
end