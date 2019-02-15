# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
require "nokogiri"

module Y2Sap
  # Creates a gui for selecting the SAP NetWeaver installation mode
  # Which products installation mode can be selected depends on the selected media
  module NWXML

    def get_nw_products(inst_env,type,db,product_dir)
      filters = get_filters(type)
      nodes   = get_nodes(filters,inst_env,db,product_dir)
      get_products(inst_env,db,nodes)
    end

  private

    def get_filters(type)
      xml     = IO.read( "/etc/sap-installation-wizard.xml" )
      doc     = Nokogiri::XML(xml)
      filters = []
      doc.xpath('//listentry').each do |node|
        f  = [];
        n  = "";
        a  = "";
        p  = "";
        s  = "";
        i  = "";
        ok = false;
        node.children.each do |child|
          case child.name
        when 'search'
          f << child.text
        when 'name'
          n = child.text
        when 'ay_xml'
          a = child.text
        when 'partitioning'
          p = child.text
        when 'script_name'
          s = child.text
        when 'inifile_params'
          i = child.text
        when 'type'
          ok = true if child.text == type
          end
          if ok
        f.each do |filter|
          p = "base_partitioning" if( p == "" )
          s = "sap_inst.sh"       if( s == "" )
          tmp = [ n, filter, a, p, s, i ]
          filters << tmp
        end
          end
        end
      end
      return filters
    end
    
    # searches the nodes from the product catalog file
    def get_nodes(filters,inst_env,db,product_dir)
       xml     = IO.read( inst_env + "/Instmaster/product.catalog" )
       doc     = Nokogiri::XML(xml)
       nodes   = []
       found   = {}
       filters.each do |tmp|
         xmlpath = tmp[1]
         if xmlpath !~ /##PD##/
           doc.xpath(xmlfilter).each do |node|
    	 atmp = [ tmp[0] , node, tmp[2], tmp[3], tmp[4], tmp[5] ]
    	 nodes << atmp
           end
         else
           xmlpath.sub!(/##DB##/,db)
           product_dir.each do |pd|
    	 pdpath = xmlpath.sub(/##PD##/,pd)
    	 next if found.has_key?(pdpath)
    	 found[pdpath] = 1
    	 #puts pdpath
    	 doc.xpath(pdpath).each do |node|
    	   #puts pdpath
    	   atmp = [ tmp[0] , node, tmp[2], tmp[3], tmp[4], tmp[5] ]
    	   nodes << atmp
    	 end
           end
         end
       end
       return nodes
    end
    
    def get_products(inst_env,db,nodes)
      xml     = IO.read( inst_env + "/Instmaster/product.catalog" )
      doc     = Nokogiri::XML(xml)
      make_hash = proc do |hash,key|
        hash[key] = Hash.new(&make_hash)
      end
      products = Hash.new(&make_hash)
    
      nodes.each do |tmp|
        name  = tmp[0]
        node  = tmp[1]
        gname = "";
        lname = "";
        #Get ID
        id = node.attribute('id').text
        node.children.each do |child|
         lname = child.text if child.name == 'display-name'
        end
        gname = lname
        #puts id
        match = /.*:(.*)\.#{db}\./.match(id)
        if match[1] != nil
          doc.xpath('//components[@output-dir="'+match[1]+'"]/display-name').each do |n1|
    	gname = n1.text
          end
        end
        if gname !~ /#{name}/
    	gname = name+" "+gname
        end
        products[gname]['name']           = gname
        products[gname]['id']             = id
        products[gname]['ay_xml']         = tmp[2]
        products[gname]['partitioning']   = tmp[3]
        products[gname]['script_name']    = tmp[4]
        products[gname]['inifile_params'] = tmp[5]
      end
      ret = []
      products.keys.sort.each do |key|
        ret << products[key]
      end
      return ret
    end
  end
end
