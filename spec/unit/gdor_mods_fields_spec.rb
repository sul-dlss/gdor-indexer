require 'spec_helper'
describe 'gdor_mods_fields mixin for SolrDocBuilder class' do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @strio = StringIO.new
  end

  before(:each) do
    @hdor_client = double()
    @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
    Indexer.stub(:config).and_return({:max_pub_date => 2013, :min_pub_date => 1})
  end

  context "sw subject methods" do
    before(:all) do
      @genre = 'genre top level'
      @cart_coord = '6 00 S, 71 30 E'
      @s_genre = 'genre in subject'
      @geo = 'Somewhere'
      @geo_code = 'us'
      @hier_geo_country = 'France'
      @s_name = 'name in subject'
      @occupation = 'worker bee'
      @temporal = 'temporal'
      @s_title = 'title in subject'
      @topic = 'topic'
      m = "<mods #{@ns_decl}>
      <genre>#{@genre}</genre>
      <subject><cartographics><coordinates>#{@cart_coord}</coordinates></cartographics></subject>
      <subject><genre>#{@s_genre}</genre></subject>
      <subject><geographic>#{@geo}</geographic></subject>
      <subject><geographicCode authority='iso3166'>#{@geo_code}</geographicCode></subject>
      <subject><hierarchicalGeographic><country>#{@hier_geo_country}</country></hierarchicalGeographic></subject>
      <subject><name><namePart>#{@s_name}</namePart></name></subject>
      <subject><occupation>#{@occupation}</occupation></subject>
      <subject><temporal>#{@temporal}</temporal></subject>
      <subject><titleInfo><title>#{@s_title}</title></titleInfo></subject>
      <subject><topic>#{@topic}</topic></subject>      
      </mods>"
      @ng_mods = Nokogiri::XML(m)
      m_no_subject = "<mods #{@ns_decl}><note>notit</note></mods>"
      @ng_mods_no_subject = Nokogiri::XML(m_no_subject)
    end
    before(:each) do
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods)      
      @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
    end

    context "search fields" do      
      context "topic_search" do
        it "should be nil if there are no values in the MODS" do
          @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.topic_search.should == nil
        end
        it "should contain subject <topic> subelement data" do
          @sdb.smods_rec.topic_search.should include(@topic)
        end
        it "should contain top level <genre> element data" do
          @sdb.smods_rec.topic_search.should include(@genre)
        end
        it "should not contain other subject element data" do
          @sdb.smods_rec.topic_search.should_not include(@cart_coord)
          @sdb.smods_rec.topic_search.should_not include(@s_genre)
          @sdb.smods_rec.topic_search.should_not include(@geo)
          @sdb.smods_rec.topic_search.should_not include(@geo_code)
          @sdb.smods_rec.topic_search.should_not include(@hier_geo_country)
          @sdb.smods_rec.topic_search.should_not include(@s_name)
          @sdb.smods_rec.topic_search.should_not include(@occupation)
          @sdb.smods_rec.topic_search.should_not include(@temporal)
          @sdb.smods_rec.topic_search.should_not include(@s_title)
        end
        it "should not be nil if there are only subject/topic elements (no <genre>)" do
          m = "<mods #{@ns_decl}><subject><topic>#{@topic}</topic></subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.topic_search.should == [@topic]
        end
        it "should not be nil if there are only <genre> elements (no subject/topic elements)" do
          m = "<mods #{@ns_decl}><genre>#{@genre}</genre></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.topic_search.should == [@genre]
        end
        context "topic subelement" do
          it "should have a separate value for each topic element" do
            m = "<mods #{@ns_decl}>
            <subject>
            <topic>first</topic>
            <topic>second</topic>
            </subject>
            <subject><topic>third</topic></subject>
            </mods>"
            @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
            sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
            sdb.smods_rec.topic_search.should == ['first', 'second', 'third']
          end
          it "should be nil if there are only empty values in the MODS" do
            m = "<mods #{@ns_decl}><subject><topic/></subject><note>notit</note></mods>"
            @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
            sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
            sdb.smods_rec.topic_search.should == nil
          end
        end
      end # topic_search

      context "geographic_search" do
        it "should call sw_geographic_search (from stanford-mods gem)" do
          m = "<mods #{@ns_decl}><subject><geographic>#{@geo}</geographic></subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.should_receive(:sw_geographic_search)
          sdb.smods_rec.geographic_search
        end
        it "should log an info message when it encounters a geographicCode encoding it doesn't translate" do
          m = "<mods #{@ns_decl}><subject><geographicCode authority='iso3166'>ca</geographicCode></subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.sw_logger.should_receive(:info).with(/#{@fake_druid} has subject geographicCode element with untranslated encoding \(iso3166\): <geographicCode authority=.*>ca<\/geographicCode>/)
          sdb.smods_rec.geographic_search
        end
      end # geographic_search

      context "subject_other_search" do
        it "should call sw_subject_names (from stanford-mods gem)" do
          @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods)
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.should_receive(:sw_subject_names)
          sdb.smods_rec.subject_other_search
        end
        it "should call sw_subject_titles (from stanford-mods gem)" do
          @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods)
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.should_receive(:sw_subject_titles)
          sdb.smods_rec.subject_other_search
        end
        it "should be nil if there are no values in the MODS" do
          @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.subject_other_search.should == nil
        end
        it "should contain subject <name> SUBelement data" do
          @sdb.smods_rec.subject_other_search.should include(@s_name)
        end
        it "should contain subject <occupation> subelement data" do
          @sdb.smods_rec.subject_other_search.should include(@occupation)
        end
        it "should contain subject <titleInfo> SUBelement data" do
          @sdb.smods_rec.subject_other_search.should include(@s_title)
        end
        it "should not contain other subject element data" do
          @sdb.smods_rec.subject_other_search.should_not include(@genre)
          @sdb.smods_rec.subject_other_search.should_not include(@cart_coord)
          @sdb.smods_rec.subject_other_search.should_not include(@s_genre)
          @sdb.smods_rec.subject_other_search.should_not include(@geo)
          @sdb.smods_rec.subject_other_search.should_not include(@geo_code)
          @sdb.smods_rec.subject_other_search.should_not include(@hier_geo_country)
          @sdb.smods_rec.subject_other_search.should_not include(@temporal)
          @sdb.smods_rec.subject_other_search.should_not include(@topic)
        end
        it "should not be nil if there are only subject/name elements" do
          m = "<mods #{@ns_decl}><subject><name><namePart>#{@s_name}</namePart></name></subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.subject_other_search.should == [@s_name]
        end
        it "should not be nil if there are only subject/occupation elements" do
          m = "<mods #{@ns_decl}><subject><occupation>#{@occupation}</occupation></subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.subject_other_search.should == [@occupation]
        end
        it "should not be nil if there are only subject/titleInfo elements" do
          m = "<mods #{@ns_decl}><subject><titleInfo><title>#{@s_title}</title></titleInfo></subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.subject_other_search.should == [@s_title]
        end
        context "occupation subelement" do
          it "should have a separate value for each occupation element" do
            m = "<mods #{@ns_decl}>
            <subject>
            <occupation>first</occupation>
            <occupation>second</occupation>
            </subject>
            <subject><occupation>third</occupation></subject>
            </mods>"
            @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
            sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
            sdb.smods_rec.subject_other_search.should == ['first', 'second', 'third']
          end
          it "should be nil if there are only empty values in the MODS" do
            m = "<mods #{@ns_decl}><subject><occupation/></subject><note>notit</note></mods>"
            @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
            sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
            sdb.smods_rec.subject_other_search.should == nil
          end
        end
      end # subject_other_search

      context "subject_other_subvy_search" do
        it "should be nil if there are no values in the MODS" do
          @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.subject_other_subvy_search.should == nil
        end
        it "should contain subject <temporal> subelement data" do
          @sdb.smods_rec.subject_other_subvy_search.should include(@temporal)
        end
        it "should contain subject <genre> SUBelement data" do
          @sdb.smods_rec.subject_other_subvy_search.should include(@s_genre)
        end
        it "should not contain other subject element data" do
          @sdb.smods_rec.subject_other_subvy_search.should_not include(@genre)
          @sdb.smods_rec.subject_other_subvy_search.should_not include(@cart_coord)
          @sdb.smods_rec.subject_other_subvy_search.should_not include(@geo)
          @sdb.smods_rec.subject_other_subvy_search.should_not include(@geo_code)
          @sdb.smods_rec.subject_other_subvy_search.should_not include(@hier_geo_country)
          @sdb.smods_rec.subject_other_subvy_search.should_not include(@s_name)
          @sdb.smods_rec.subject_other_subvy_search.should_not include(@occupation)
          @sdb.smods_rec.subject_other_subvy_search.should_not include(@topic)
          @sdb.smods_rec.subject_other_subvy_search.should_not include(@s_title)
        end
        it "should not be nil if there are only subject/temporal elements (no subject/genre)" do
          m = "<mods #{@ns_decl}><subject><temporal>#{@temporal}</temporal></subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.subject_other_subvy_search.should == [@temporal]
        end
        it "should not be nil if there are only subject/genre elements (no subject/temporal)" do
          m = "<mods #{@ns_decl}><subject><genre>#{@s_genre}</genre></subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.subject_other_subvy_search.should == [@s_genre]
        end
        context "temporal subelement" do
          it "should have a separate value for each temporal element" do
            m = "<mods #{@ns_decl}>
            <subject>
            <temporal>1890-1910</temporal>
            <temporal>20th century</temporal>
            </subject>
            <subject><temporal>another</temporal></subject>
            </mods>"
            @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
            sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
            sdb.smods_rec.subject_other_subvy_search.should == ['1890-1910', '20th century', 'another']
          end
          it "should log an info message when it encounters an encoding it doesn't translate" do
            m = "<mods #{@ns_decl}><subject><temporal encoding='iso8601'>197505</temporal></subject></mods>"
            @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
            sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
            sdb.smods_rec.sw_logger.should_receive(:info).with(/#{@fake_druid} has subject temporal element with untranslated encoding: <temporal encoding=.*>197505<\/temporal>/)
            sdb.smods_rec.subject_other_subvy_search
          end
          it "should be nil if there are only empty values in the MODS" do
            m = "<mods #{@ns_decl}><subject><temporal/></subject><note>notit</note></mods>"
            @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
            sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
            sdb.smods_rec.subject_other_subvy_search.should == nil
          end
        end
        context "genre subelement" do
          it "should have a separate value for each genre element" do
            m = "<mods #{@ns_decl}>
            <subject>
            <genre>first</genre>
            <genre>second</genre>
            </subject>
            <subject><genre>third</genre></subject>
            </mods>"
            @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
            sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
            sdb.smods_rec.subject_other_subvy_search.should == ['first', 'second', 'third']
          end
          it "should be nil if there are only empty values in the MODS" do
            m = "<mods #{@ns_decl}><subject><genre/></subject><note>notit</note></mods>"
            @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
            sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
            sdb.smods_rec.subject_other_subvy_search.should == nil
          end
        end
      end # subject_other_subvy_search

      context "subject_all_search" do
        it "should be nil if there are no values in the MODS" do
          @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.subject_all_search.should == nil
        end
        it "should contain top level <genre> element data" do
          @sdb.smods_rec.subject_all_search.should include(@genre)
        end
        it "should not contain cartographic sub element" do
          @sdb.smods_rec.subject_all_search.should_not include(@cart_coord)
        end
        it "should not include codes from hierarchicalGeographic sub element" do
          @sdb.smods_rec.subject_all_search.should_not include(@geo_code)
        end
        it "should contain all other subject subelement data" do
          @sdb.smods_rec.subject_all_search.should include(@s_genre)
          @sdb.smods_rec.subject_all_search.should include(@geo)
          @sdb.smods_rec.subject_all_search.should include(@hier_geo_country)
          @sdb.smods_rec.subject_all_search.should include(@s_name)
          @sdb.smods_rec.subject_all_search.should include(@occupation)
          @sdb.smods_rec.subject_all_search.should include(@temporal)
          @sdb.smods_rec.subject_all_search.should include(@s_title)
          @sdb.smods_rec.subject_all_search.should include(@topic)
        end
      end # subject_all_search
    end # subject search fields

    context "facet fields" do
      context "topic_facet" do
        it "should include topic subelement" do
          @sdb.smods_rec.topic_facet.should include(@topic)
        end
        it "should include sw_subject_names" do
          @sdb.smods_rec.topic_facet.should include(@s_name)
        end
        it "should include sw_subject_titles" do
          @sdb.smods_rec.topic_facet.should include(@s_title)
        end
        it "should include occupation subelement" do
          @sdb.smods_rec.topic_facet.should include(@occupation)
        end
        it "should have the trailing punctuation removed" do
          m = "<mods #{@ns_decl}><subject>
          <topic>comma,</topic>
          <occupation>semicolon;</occupation>
          <titleInfo><title>backslash \\</title></titleInfo>
          <name><namePart>internal, punct;uation</namePart></name>
          </subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.topic_facet.should include('comma')
          sdb.smods_rec.topic_facet.should include('semicolon')
          sdb.smods_rec.topic_facet.should include('backslash')
          sdb.smods_rec.topic_facet.should include('internal, punct;uation')
        end
        it "should be nil if there are no values" do
          @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.topic_facet.should == nil
        end
      end
      context "geographic_facet" do
        it "should call geographic_search" do
          @sdb.smods_rec.should_receive(:geographic_search)
          @sdb.smods_rec.geographic_facet
        end
        it "should be like geographic_search with the trailing punctuation (and preceding spaces) removed" do
          m = "<mods #{@ns_decl}><subject>
          <geographic>comma,</geographic>
          <geographic>semicolon;</geographic>
          <geographic>backslash \\</geographic>
          <geographic>internal, punct;uation</geographic>
          </subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.geographic_facet.should include('comma')
          sdb.smods_rec.geographic_facet.should include('semicolon')
          sdb.smods_rec.geographic_facet.should include('backslash')
          sdb.smods_rec.geographic_facet.should include('internal, punct;uation')
        end
        it "should be nil if there are no values" do
          @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.geographic_facet.should == nil
        end
      end
      context "era_facet" do
        it "should be temporal subelement with the trailing punctuation removed" do
          m = "<mods #{@ns_decl}><subject>
          <temporal>comma,</temporal>
          <temporal>semicolon;</temporal>
          <temporal>backslash \\</temporal>
          <temporal>internal, punct;uation</temporal>
          </subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.era_facet.should include('comma')
          sdb.smods_rec.era_facet.should include('semicolon')
          sdb.smods_rec.era_facet.should include('backslash')
          sdb.smods_rec.era_facet.should include('internal, punct;uation')
        end
        it "should be nil if there are no values" do
          @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          sdb.smods_rec.era_facet.should == nil
        end
      end
    end # subject facet fields
    context "pub_dates" do
      it "should choose the first date" do
        m = "<mods #{@ns_decl}><originInfo>
        <dateCreated>1904</dateCreated>
        <dateCreated>1904</dateCreated>
        <dateIssued>1906</dateIssued>

        </originInfo></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.smods_rec.pub_dates.should == ['1906','1904','1904']
      end
    end
  end # context sw subject methods 
  
  context "pub_date" do
    it "should choose the first date" do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>1904</dateCreated>
      </originInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.smods_rec.pub_date.should == '1904'
    end
    it "should correctly parse a ranged date" do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>Text dated June 4, 1594; miniatures added by 1596</dateCreated>
      </originInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.smods_rec.pub_date.should == '1594'
    end
    it "should parse a date" do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>Aug. 3rd, 1886</dateCreated>
      </originInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.pub_date.should == '1886'
    end
    it "should remove question marks and brackets" do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>Aug. 3rd, [18]86?</dateCreated>
      </originInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.pub_date.should == '1886'
    end
    it 'should handle an s after the decade' do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>early 1890s</dateCreated>
      </originInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.pub_date.should == '1890'
    end
    it "should ignore a date if it falls outside the constraints" do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>1904</dateCreated>
      </originInfo></mods>"
      Indexer.stub(:config).and_return({:max_pub_date => 1000, :min_pub_date => 1})
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.pub_date.should == nil
    end
    it 'should choose a date ending with CE if there are multiple dates' do
     m = "<mods #{@ns_decl}><originInfo><dateIssued>7192 AM (li-Adam) / 1684 CE</dateIssued><issuance>monographic</issuance></originInfo>"
     @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
     sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
     sdb.pub_date.should == '1684'
    end
    it 'should handle hyphenated range dates' do
      m = "<mods #{@ns_decl}><originInfo><dateIssued>1282 AH / 1865-6 CE</dateIssued><issuance>monographic</issuance></originInfo>"
       @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
       sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
       sdb.pub_date.should == '1865'
    end
    it 'should handle century based dates' do
      m = "<mods #{@ns_decl}><originInfo><dateIssued>13th century AH / 19th CE</dateIssued><issuance>monographic</issuance></originInfo>"
       @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
       sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
       sdb.smods_rec.pub_date_facet.should == '19th century'
       sdb.smods_rec.pub_date_sort.should =='1800'
       sdb.smods_rec.pub_date.should == '18--'
    end
    it 'should handle multiple CE dates' do
      m = "<mods #{@ns_decl}><originInfo><dateIssued>6 Dhu al-Hijjah 923 AH / 1517 CE -- 7 Rabi I 924 AH / 1518 CE</dateIssued><issuance>monographic</issuance></originInfo>"
       @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
       sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
       sdb.smods_rec.pub_date.should == '1517'
       sdb.smods_rec.pub_date_sort.should =='1517'
       sdb.smods_rec.pub_date_facet.should == '1517'
    end
    it 'should handle this case from walters' do
      m = "<mods #{@ns_decl}><originInfo><dateIssued>Late 14th or early 15th century CE</dateIssued><issuance>monographic</issuance></originInfo>"
       @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
       sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
       sdb.smods_rec.pub_date.should == '14--'
       sdb.smods_rec.pub_date_sort.should =='1400'
       sdb.smods_rec.pub_date_facet.should == '15th century'
    end
    it 'should work on 3 digit dates' do
      m = "<mods #{@ns_decl}><originInfo><dateIssued>966 CE</dateIssued><issuance>monographic</issuance></originInfo>"
       @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
       sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
       sdb.smods_rec.pub_date.should == '966'
       sdb.smods_rec.pub_date_sort.should =='0966'
       sdb.smods_rec.pub_date_facet.should == '966'
    end
    it 'should work on 3 digit dates' do
      m = "<mods #{@ns_decl}><originInfo><dateIssued>3rd century AH / 9th CE</dateIssued><issuance>monographic</issuance></originInfo>"
       @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
       sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
       sdb.smods_rec.pub_date.should == '8--'
       sdb.smods_rec.pub_date_sort.should =='0800'
       sdb.smods_rec.pub_date_facet.should == '9th century'
    end
    it 'should work on 3 digit BC dates' do
      m = "<mods #{@ns_decl}><originInfo><dateCreated>300 B.C.</dateCreated></originInfo>"
       @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
       sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
       sdb.smods_rec.pub_year.should == '-700'
       sdb.smods_rec.pub_date.should == '-700'
       sdb.smods_rec.pub_date_sort.should =='-700'
       sdb.smods_rec.pub_date_facet.should == '300 B.C.'
    end
  end #context pub_dates
  
  context 'pub_date_sort' do
    before :each do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>Aug. 3rd, 1886</dateCreated>
      </originInfo></mods>"
       @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
       @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
    end
    it 'should work on normal dates' do
      @sdb.smods_rec.stub(:pub_date).and_return('1945')
      @sdb.smods_rec.pub_date_sort.should == '1945'
    end
    it 'should work on 3 digit dates' do
      @sdb.smods_rec.stub(:pub_date).and_return('945')
      @sdb.smods_rec.pub_date_sort.should == '0945'
    end
    it 'should work on century dates' do
      @sdb.smods_rec.stub(:pub_date).and_return('16--')
      @sdb.smods_rec.pub_date_sort.should == '1600'
    end
    it 'should work on 3 digit century dates' do
      @sdb.smods_rec.stub(:pub_date).and_return('9--')
      @sdb.smods_rec.pub_date_sort.should == '0900'
    end
  end
  
  context "format" do
    it "should get format from call to stanford-mods searchworks format method " do
      m = "<mods #{@ns_decl}><typeOfResource>still image</typeOfResouce></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.smods_rec.should_receive(:format).and_call_original
      sdb.smods_rec.format.should == ['Image']
    end
    it "should add a format from a config file" do
      m = "<mods #{@ns_decl}><typeOfResource>still image</typeOfResouce></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      Indexer.stub(:config).and_return({:add_format => 'Map / Globe'})
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.format.should == ['Image', 'Map / Globe']
    end
    it "should include formats from the Indexer.coll_formats_from_items when the druid matches" do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>1904</dateCreated>
      </originInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      Indexer.stub(:coll_formats_from_items).and_return({@fake_druid=>['Image']})
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.format.should == ['Image']
    end
    it "should not include formats from the Indexer.coll_formats_from_items when the druid doesn't match" do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>1904</dateCreated>
      </originInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      Indexer.stub(:coll_formats_from_items).and_return({'foo'=>['Image']})
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.format.should == []
    end
    it "should return nothing if there is no format info" do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>1904</dateCreated>
      </originInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.smods_rec.format.should == []
    end
    context "collection_formats should aggregate item formats" do
      it "should not have duplicate values" do
        m = "<mods #{@ns_decl}>
          <note>hi</note>
        </mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        Indexer.stub(:coll_formats_from_items).and_return({@fake_druid=>['Image', 'Video', 'Image']})
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.format.should == ['Image', 'Video']
      end
    end # collection_formats
  end # context format
  
  context "pub_date_groups" do
    it 'should generate the groups' do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>1904</dateCreated>
      </originInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.smods_rec.pub_date_groups(1904).should == ['More than 50 years ago']
    end
    it 'should work for a modern date too' do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>1904</dateCreated>
      </originInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.smods_rec.pub_date_groups(2013).should == ["This year"]
    end
    it 'should work ok given a nil date' do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>1904</dateCreated>
      </originInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.smods_rec.pub_date_groups(nil).should == nil
    end
  end # context pub date groups
  
  context 'catkey' do
    it 'should be nil if there is no catkey' do
      m = "<mods #{@ns_decl}><recordInfo>
        <descriptionStandard>dacs</descriptionStandard>
      </recordInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.catkey.should == nil
    end
    it "populated when source attribute is SIRSI" do
      m = "<mods #{@ns_decl}><recordInfo>
        <recordIdentifier source=\"SIRSI\">a6780453</recordIdentifier>
      </recordInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.catkey.should_not == nil
    end
    it "not populated when source attribute is not SIRSI" do
      m = "<mods #{@ns_decl}><recordInfo>
        <recordIdentifier source=\"FOO\">a6780453</recordIdentifier>
      </recordInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.catkey.should == nil
    end
    it "should remove the a at the beginning of the catkey" do
      m = "<mods #{@ns_decl}><recordInfo>
        <recordIdentifier source=\"SIRSI\">a6780453</recordIdentifier>
      </recordInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.catkey.should == '6780453'
    end
  end # catkey
  
end