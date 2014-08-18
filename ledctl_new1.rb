#!/usr/local/bin/ruby
#2014-07-14 discus with J.K  when he scan all hardisks on monitor and get all disks failed on which slots .
#1'st ledctl [off/on] all    
#2'ed ledctl on  1:2,4.....	  "1"=>NAS, after are expend box or enclosure box.
#3'rd ledctl off 2:3,5....     
#4'th ledctl --info

dev_sg=Array.new()
text=String.new()
ses_slots_1=0                   #for ses board hwmon1 slots counts
ses_slots_2=0                   #for ses board hwmon2 slots counts
@tmp=0
@isInband=`cat /nas/config/disknum`
@isInband.chomp!

@isZFS =`ls /nas/config/isZFS 2>/dev/null`
@isZFS.chomp!

@hwmon=Hash.new()                        										#To save encboard hwmontX
@column=`ls /sys/class/hwmon/ -l`.split(/\n/)									#scan all hardware monitor files
hw1_stat=0
hw2_stat=0

def do_linkbox_countbox()   
	text =`ls /dev/sg*`
    text.chomp!
    dev_sg=text.split("\n")
	boxnum=0
	total_box=0
	for i in 1..(dev_sg.length-1)
		text = `sg_ses --join --filter #{dev_sg[i]} 2>/dev/null |grep hex |awk -F ": " '{print $2}'`
		if text !=""
			`ln -sf #{dev_sg[i]} /dev/box#{boxnum}`
			boxnum+=1
			total_box+=1
		end	
	end
	return total_box
end


def led_info()
	inband = "Yes"
	zfs = "Yes"
	enc="0" 
	 sas_addrs=Array.new()
	if @isInband=="1" && @isZFS=="/nas/config/isZFS"		# Inband 
		if ! File.exist?("/nas/config/isInbandLED")
			`touch /nas/config/isInbandLED`
		end
		
		if ! File.exist?("/nas/config/boxnum")			# first time call us	
			`echo #{@tmp} > /nas/config/boxnum`
			
		else
			box_num=`cat /nas/config/boxnum`			# check if new enclosure box added!
			
			if  @tmp != box_num.to_i						#  new enclosure box .
				`echo #{@tmp} > /nas/config/boxnum`
			end
			text=`ls /dev/box*`
			text.chomp!
			text=text.delete("/dev/box")
			enc=text.gsub(/\n/,',')
			text=enc.split(",")
			for i in 0...text.length
                sas_addrs[i]=`sg_ses --join --filter /dev/box#{text[i]}  |grep hex |awk -F ": " '{print $2}'`
            end
            print  "inband:#{inband}\n"
            print  "zfs:#{zfs}\n"
            print  "enc:#{enc}\n"
            for i in 0...sas_addrs.length
                print "SAS_Address:/dev/box",i,":",sas_addrs[i]
            end

	   end
	elsif @isInband !="1" && @isZFS=="/nas/config/isZFS"
		inband="No"
		enc="0"
		for i in 1...@column.size

			if @column[i].index("usb2") && @column[i].index("001f")                 #nas led 1~8
					 str=@column[i]
					 str.chomp!
					 @hwmon["nas1_1"]="hwmon"+str[str.length-1]
			end

			if @column[i].index("usb2") && @column[i].index("001e")                 #nas led 9-16
					 str=@column[i]
					 str.chomp!
					 @hwmon["nas1_2"]="hwmon"+str[str.length-1]
			end

			if !@column[i].index("usb2") && @column[i].index("001f")                 #expand box 1~8
					 str=@column[i]
					 str.chomp!
					 @hwmon["expbox1_1"]="hwmon"+str[str.length-1]
			end

			if !@column[i].index("usb2") && @column[i].index("001e")                 #expand box 9~16
					 str=@column[i]
					 str.chomp!
					 @hwmon["expbox1_2"]="hwmon"+str[str.length-1]
			end

		end
		print  "inband:#{inband}\n"
		print  "zfs:#{zfs}\n"
		print  "enc:#{enc}\n"
		@hwmon.each{|key,value|
		print key,"=>",value,"\n"
		}
	else
		inband="Unknow"
		zfs = "No"
		enc="0"
		print  "inband:#{inband}\n"
		print  "zfs:#{zfs}\n"
		print  "enc:#{enc}\n"
	end
	
end

if  @isInband=="1" && @isZFS=="/nas/config/isZFS"
		`rm /dev/box* 2>/dev/null`
		@tmp=do_linkbox_countbox()								# get how many enclosure box now and do link
		if ! File.exist?("/nas/config/isInbandLED")
			`touch /nas/config/isInbandLED`
		end
	    if ! File.exist?("/nas/config/boxnum")			# first time call us	
			`echo #{@tmp} > /nas/config/boxnum`
		else
			box_num=`cat /nas/config/boxnum`			# check if new enclosure box added!
			
			if  @tmp != box_num.to_i						#  new enclosure box .
				`echo #{@tmp} > /nas/config/boxnum`
			end
	   end
    
    if ARGV[0] =="on" && ARGV[1]!=nil 
	
        if ARGV[1]=="all"
			text=`ls /dev/box*`
			text.chomp!
			dev_sg=text.split("\n")
		   for x in 0..(dev_sg.length-1)
				for i in 0..15
                         `sg_ses -I #{i} -S fault=1 #{dev_sg[x]} 2>/dev/null`
				end
			end
        elsif ARGV[1]!=nil
				dev_sg=ARGV[1].split(":")
				if dev_sg.length != 2
					print "Error option : #{ARGV[1]}\n"
				else
					which_box=dev_sg[0].to_i
					which_box -=1;							# our NAS is number is 1 =>  ledctl on 1:2,4    => NAS led on  on slot 2,4
					which_disks=dev_sg[1].split(",")
				
					# turn string array to integer array
					for i in 0..(which_disks.length-1)
						which_disks[i]=which_disks[i].to_i
					end	
				
					# light on led
					for i in 0..(which_disks.length-1)
						which_disks[i]-=1
						if which_disks[i] >= 0
							`sg_ses -I #{which_disks[i]} -S fault=1 /dev/box#{which_box}`
						end
					#    print "sg_ses -I ",text[i]," -S ident=1 /dev/led\n"
					end
				end
		else
			print "Error option ! \n"
        end
			
        
    elsif ARGV[0] =="off" && ARGV[1]!=nil
		if ARGV[1]=="all"
		   text=`ls /dev/box*`
		   text.chomp!
		   dev_sg=text.split("\n")
		   for x in 0..(dev_sg.length-1)
				for i in 0..15
                         `sg_ses -I #{i} -S fault=0 #{dev_sg[x]} 2>/dev/null`
				end
			end
        elsif ARGV[1]!=nil 
				dev_sg=ARGV[1].split(":")
				if dev_sg.length != 2
					print "Error option : #{ARGV[1]}\n"
				else
					which_box=dev_sg[0].to_i
					which_box -=1								# our NAS is number is 1 =>  ledctl off 1:2,4    => NAS led off  on slot 2,4 
					which_disks=dev_sg[1].split(",")
				
					# turn string array to integer array
					for i in 0..(which_disks.length-1)
						which_disks[i]=which_disks[i].to_i
					end	
				
					# light on led
					for i in 0..(which_disks.length-1)
						which_disks[i]-=1
						if which_disks[i] >= 0
							`sg_ses -I #{which_disks[i]} -S fault=0 /dev/box#{which_box}`
						end
					#    print "sg_ses -I ",text[i]," -S ident=1 /dev/led\n"
					end
				end
		else
			print "Error option ! \n"
        end	
     
	elsif ARGV[0]=="--info"
		led_info()
    else
        print "Error option!\n"
    end
elsif @isZFS=="/nas/config/isZFS" && @isInband !="1"
      #Ses-board control

             #by Clover 2014-07-14
             #light on led, if light 1's led  echo 1 , if light 2'ed echo 2 ,if light 3'rd echo 4

             #===================================================================
             #so led number 1  |   2  |   3  |   4  |   5  |   6  |   7  |   8
             # echo  value  1  |   2  |   4  |   8  |   16 |   32 |   64 |  128
             #===================================================================

             #if you want light on 1,2,3 and 4 leds at the same time.
             #     you need echo (1+2+4+8) > /sys/class/hwmon/hwmon1/device/ledstate

             #if you light on over 9'rd leds. you need echo (X) > /sys/class/hwmon/hwmon2/device/ledstate
             # echo 0 > ........at the hwmon'X', the hwmon'X'  all off

	encbd_count=`lsusb|grep c631|awk '{print NR}'`				#	get 1 encboard or 2
	encbd_count.chomp!
	encbd_count=encbd_count.gsub(/\n/,' ')
	

	for i in 1...@column.size

			if @column[i].index("usb2") && @column[i].index("001f")                 #nas led 1~8
					 str=@column[i]
					 str.chomp!
					 @hwmon["nas1_1"]="hwmon"+str[str.length-1]
			end

			if @column[i].index("usb2") && @column[i].index("001e")                 #nas led 9-16
					 str=@column[i]
					 str.chomp!
					 @hwmon["nas1_2"]="hwmon"+str[str.length-1]
			end

			if !@column[i].index("usb2") && @column[i].index("001f")                 #expand box 1~8
					 str=@column[i]
					 str.chomp!
					 @hwmon["expbox1_1"]="hwmon"+str[str.length-1]
			end

			if !@column[i].index("usb2") && @column[i].index("001e")                 #expand box 9~16
					 str=@column[i]
					 str.chomp!
					 @hwmon["expbox1_2"]="hwmon"+str[str.length-1]
			end

	end
	if encbd_count[encbd_count.length-1] =="2"										#High point HBA with expend box
	

			`chmod 600 /sys/class/hwmon/#{@hwmon["nas1_1"]}/device/ledstate`
			`chmod 600 /sys/class/hwmon/#{@hwmon["nas1_2"]}/device/ledstate`
			`chmod 600 /sys/class/hwmon/#{@hwmon["expbox1_1"]}/device/ledstate`
			`chmod 600 /sys/class/hwmon/#{@hwmon["expbox1_2"]}/device/ledstate`
			hw1_1_stat=`cat /sys/class/hwmon/#{@hwmon["nas1_1"]}/device/ledstate`.to_i			#nas enc 1-8 led
			hw1_2_stat=`cat /sys/class/hwmon/#{@hwmon["nas1_2"]}/device/ledstate`.to_i			#nas enc 9-16 led
			hw2_1_stat=`cat /sys/class/hwmon/#{@hwmon["expbox1_1"]}/device/ledstate`.to_i			#expend-box 1-8
			hw2_2_stat=`cat /sys/class/hwmon/#{@hwmon["expbox1_2"]}/device/ledstate`.to_i			#expend-box 9-16
		if ARGV[0] =="on" && ARGV[1]!=nil

			if ARGV[1]=="all"
				`echo 255 > /sys/class/hwmon/#{@hwmon["nas1_1"]}/device/ledstate`				
				`echo 255 > /sys/class/hwmon/#{@hwmon["nas1_2"]}/device/ledstate`
				`echo 255 > /sys/class/hwmon/#{@hwmon["expbox1_1"]}/device/ledstate`
				`echo 255 > /sys/class/hwmon/#{@hwmon["expbox1_2"]}/device/ledstate`
			else

				dev_sg=ARGV[1].split(":")	# 1 enclosure box so check it
				text=dev_sg[1].split(",") 	# get slot number
				ses_slots_1_1=hw1_1_stat
				ses_slots_1_2=hw1_2_stat
				ses_slots_2_1=hw2_1_stat
				ses_slots_2_2=hw2_2_stat

				#turn string array to integer
				for i in 0..(text.length-1)

				  text[i]=text[i].to_i

				end
				
				if dev_sg[0] =="1"
					for i in 0..(text.length-1)
						if text[i]>=1 && text[i] <=8                   #hwmon1_1
						  text[i] -=1
						  @tmp= 1 << text[i]
						  ses_slots_1_1=@tmp|hw1_1_stat
						  hw1_1_stat=ses_slots_1_1
						elsif text[i] >= 9 && text[i] <=16                #hwmon1_2
						  text[i] -= 9
						  @tmp = 1 << text[i]
						  ses_slots_1_2 = @tmp|hw1_2_stat
						  hw1_2_stat=ses_slots_1_2
						end
					end

					   `echo #{ses_slots_1_1} > /sys/class/hwmon/#{@hwmon["nas1_1"]}/device/ledstate`

					   `echo #{ses_slots_1_2} > /sys/class/hwmon/#{@hwmon["nas1_2"]}/device/ledstate`
				elsif dev_sg[0]=="2"
					for i in 0..(text.length-1)
						if text[i]>=1 && text[i] <=8                   #hwmon2_1
						  text[i] -=1
						  @tmp= 1 << text[i]
						  ses_slots_2_1=@tmp|hw2_1_stat
						  hw2_1_stat=ses_slots_2_1
						elsif text[i] >= 9 && text[i] <=16                #hwmon2_2
						  text[i] -= 9
						  @tmp = 1 << text[i]
						  ses_slots_2_2 = @tmp|hw2_2_stat
						  hw2_2_stat=ses_slots_2_2
						end
					end

					   `echo #{ses_slots_2_1} > /sys/class/hwmon/#{@hwmon["expbox1_1"]}/device/ledstate`

					   `echo #{ses_slots_2_2} > /sys/class/hwmon/#{@hwmon["expbox1_2"]}/device/ledstate`
				end
			end
		elsif ARGV[0] =="off" && ARGV[1]!=nil

			if  ARGV[1]=="all"
					`echo 0 > /sys/class/hwmon/#{@hwmon["nas1_1"]}/device/ledstate`
					`echo 0 > /sys/class/hwmon/#{@hwmon["nas1_2"]}/device/ledstate`
					`echo 0 > /sys/class/hwmon/#{@hwmon["expbox1_1"]}/device/ledstate`
					`echo 0 > /sys/class/hwmon/#{@hwmon["expbox1_2"]}/device/ledstate`
			else


				dev_sg=ARGV[1].split(":")	#  1 enclosure box so check it
				text=dev_sg[1].split(",") 	# get slot number
				ses_slots_1_1=hw1_1_stat
				ses_slots_1_2=hw1_2_stat
				ses_slots_2_1=hw2_1_stat
				ses_slots_2_2=hw2_2_stat

				 #turn string array to integer
				 for i in 0..(text.length-1)

				   text[i]=text[i].to_i

				 end
				
				if dev_sg[0]=="1"
					 #led off
					 for i in 0..(text.length-1)
						if text[i]>=1 && text[i] <=8                   #hwmon1_1
						  text[i] -= 1
						  @tmp= 1 << text[i]
						  ses_slots_1_1=@tmp^hw1_1_stat
						  hw1_1_stat=ses_slots_1_1
						elsif text[i] >= 9 && text[i] <=16                #hwmon1_2
						  text[i] -= 9
						  @tmp = 1 << text[i]
						  ses_slots_1_2 = @tmp^hw1_2_stat
						  hw1_2_stat=ses_slots_1_2
						end

					 end

					   `echo #{ses_slots_1_1} > /sys/class/hwmon/#{@hwmon["nas1_1"]}/device/ledstate`

					   `echo #{ses_slots_1_2} > /sys/class/hwmon/#{@hwmon["nas1_2"]}/device/ledstate`
				elsif dev_sg[0]=="2"
					#led off
					 for i in 0..(text.length-1)
						if text[i]>=1 && text[i] <=8                   #hwmon2_1
						  text[i] -= 1
						  @tmp= 1 << text[i]
						  ses_slots_2_1=@tmp^hw2_1_stat
						  hw2_1_stat=ses_slots_2_1
						elsif text[i] >= 9 && text[i] <=16                #hwmon2_2
						  text[i] -= 9
						  @tmp = 1 << text[i]
						  ses_slots_2_2 = @tmp^hw2_2_stat
						  hw2_2_stat=ses_slots_2_2
						end

					 end

					   `echo #{ses_slots_2_1} > /sys/class/hwmon/#{@hwmon["expbox1_1"]}/device/ledstate`

					   `echo #{ses_slots_2_2} > /sys/class/hwmon/#{@hwmon["expbox1_2"]}/device/ledstate`
				end
			end
		elsif ARGV[0]=="--info"
			led_info()	
		else
			print "Error option!\n"

		end
	
	elsif encbd_count[encbd_count.length-1] =="1"	
			`chmod 600 /sys/class/hwmon/#{@hwmon["nas1_1"]}/device/ledstate`
			`chmod 600 /sys/class/hwmon/#{@hwmon["nas1_2"]}/device/ledstate`
			hw1_stat=`cat /sys/class/hwmon/#{@hwmon["nas1_1"]}/device/ledstate`.to_i
			hw2_stat=`cat /sys/class/hwmon/#{@hwmon["nas1_2"]}/device/ledstate`.to_i
		if ARGV[0] =="on" && ARGV[1]!=nil

			if ARGV[1]=="all"
				`echo 255 > /sys/class/hwmon/#{@hwmon["nas1_1"]}/device/ledstate`
				`echo 255 > /sys/class/hwmon/#{@hwmon["nas1_2"]}/device/ledstate`
			else

				dev_sg=ARGV[1].split(":")	# no enclosure box so pass enclosure number
				text=dev_sg[1].split(",") 	# get slot number
				ses_slots_1=hw1_stat
				ses_slots_2=hw2_stat

				#turn string array to integer
				for i in 0..(text.length-1)

				  text[i]=text[i].to_i

				end
				
				for i in 0..(text.length-1)
					if text[i]>=1 && text[i] <=8                   #hwmon1
					  text[i] -=1
					  @tmp= 1 << text[i]
					  ses_slots_1=@tmp|hw1_stat
					  hw1_stat=ses_slots_1
					elsif text[i] >= 9 && text[i] <=16                #hwmon2
					  text[i] -= 9
					  @tmp = 1 << text[i]
					  ses_slots_2 = @tmp|hw2_stat
					  hw2_stat=ses_slots_2
					end
				end

				   `echo #{ses_slots_1} > /sys/class/hwmon/#{@hwmon["nas1_1"]}/device/ledstate`

				   `echo #{ses_slots_2} > /sys/class/hwmon/#{@hwmon["nas1_2"]}/device/ledstate`

			end
		elsif ARGV[0] =="off" && ARGV[1]!=nil

			if  ARGV[1]=="all"
					`echo 0 > /sys/class/hwmon/#{@hwmon["nas1_1"]}/device/ledstate`
					`echo 0 > /sys/class/hwmon/#{@hwmon["nas1_2"]}/device/ledstate`
			else


				dev_sg=ARGV[1].split(":")	# no enclosure box so pass enclosure number
				text=dev_sg[1].split(",") 	# get slot number
				 ses_slots_1=hw1_stat
				 ses_slots_2=hw2_stat

				 #turn string array to integer
				 for i in 0..(text.length-1)

				   text[i]=text[i].to_i

				 end

				 #led off
				 for i in 0..(text.length-1)
					if text[i]>=1 && text[i] <=8                   #hwmon1
					  text[i] -= 1
					  @tmp= 1 << text[i]
					  ses_slots_1=@tmp^hw1_stat
					  hw1_stat=ses_slots_1
					elsif text[i] >= 9 && text[i] <=16                #hwmon2
					  text[i] -= 9
					  @tmp = 1 << text[i]
					  ses_slots_2 = @tmp^hw2_stat
					  hw2_stat=ses_slots_2
					end

				 end

				   `echo #{ses_slots_1} > /sys/class/hwmon/#{@hwmon["nas1_1"]}/device/ledstate`

				   `echo #{ses_slots_2} > /sys/class/hwmon/#{@hwmon["nas1_2"]}/device/ledstate`
			end
		elsif ARGV[0]=="--info"
			led_info()	
		else
			print "Error option!\n"

		end
	end
end
