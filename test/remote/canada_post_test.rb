require 'test_helper'

class CanadaPostTest < Test::Unit::TestCase
  
  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    login = fixtures(:canada_post)
    
    @request  = xml_fixture('canadapost/example_request')    
    @response_with_postal_outlets = xml_fixture('canadapost/example_response_with_postal_outlet')
    @carrier   = CanadaPost.new(login[:login])
    
    @origin      = {:address1 => "61A York St", :city => "Ottawa", :province => "Ontario", :country => "Canada", :postal_code => "K1N 5T2"}
    @destination = {:city => "Beverly Hills", :state => "CA", :country => "United States", :postal_code => "90210"}
    @line_items  = [{:price => 10.00, :weight => 5.00, :width => 3.00, :height => 4.00, :length => 2.00, :quantity => 1, :description => "a box full of stuff"}]
  end
  
  def test_valid_credentials
    @carrier.expects(:build_rate_request).returns(@request)
    assert @carrier.valid_credentials?
  end
  
  def test_find_rates
    rates = @carrier.find_rates(@origin, @destination, 24, @line_items)    
    assert_instance_of CanadaPost::CanadaPostRateResponse, rates
  end
  
  def test_postal_outlets
    @carrier.expects(:ssl_post).returns(@response_with_postal_outlets)
    rates = @carrier.find_rates(@origin, @destination, 24, @line_items)    
    
    rates.postal_outlets.each do |outlet|
      assert_instance_of CanadaPost::PostalOutlet, outlet
    end
  end
  
end