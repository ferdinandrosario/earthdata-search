require 'spec_helper'

describe "Dataset Granule Count", reset: false do
  before :all do
    Capybara.reset_sessions!
    visit '/search?q=C16893867-LPDAAC'
    wait_for_xhr
  end

  it 'displays many granules for the given dataset' do
    expect(page). to have_content('778216 Granules')
  end

  context 'when applying search constraint' do
    before :all do
      click_link "Temporal"
      fill_in "Start", with: "2014-12-01 00:00:00\t"
      # close_datetimepicker
      js_click_apply ".temporal-dropdown"
      wait_for_xhr
    end

    it 'displays an updated granule count' do
      expect(page).to have_content('0 Granules')
    end
  end
end
