$(function() {

		//REPLACE DEVICE UNIQUE IDENTIFIER / SERIAL NUMBER HERE
		var myDevice = '00:02:f7:f0:00:00'; //default unique device identifier

		//REPLACE WITH FULL APP DOMAIN IF RUNNING LOCALLY, OTHEWISE LEAVE AS "/"
    var app_domain = '/';
		var websocket_domain = 'wss://' + document.location.hostname


		var data = [];
		var updateInterval = 5; //seconds for graph
		var timeWindow = 60; //minutes default graphing window

		var red_color = '#6B0023';
		var t;
		var control = 0;
		var tempset;
		var ts_counter = 1;
		var last_status = "UNKNOWN"

		var getkv = 1;

		var graph_options = {
        series: {
            lines: { show: true, lineWidth: 1.5, fill: false},
            points: { show: false, radius: 0.7, fillColor: "#41C4DC" }
        },
				legend: {
					position: "nw",
					backgroundColor: "#111111",
					backgroundOpacity: 0.8
				},
        yaxis: {
          min: 0,
          max: 125
        },
        xaxis: {
          mode: "time",
					timeformat: "%b-%e %I:%M %p",
					timezone:  "browser"
        },
        colors: ["#2C9DB6","#FF921E","#FF5847","#FFC647", "#5D409C", "#BF427B","#D5E04D" ]
				/*,threshold: {
					below: t,
					color: "rgb(200, 20, 30)"
				}*/
		};

		$("#specificdevice").text(myDevice);
		$("#currentdevice").text(myDevice);
    $("#appstatus").text('Running');
    $("#appstatus").css('color', '555555');
    $("#appconsole").text('starting...');
    $("#appconsole").css('color', '#555555');
		$("#graphmessage").text('Graph: Retrieving Data Now....');



		function startwebsocket() {
			console.log('starting websocket connectino to Murano Custom API');
			console.log('domain:'+app_domain);

			if ("WebSocket" in window)
	    {
				$("#appstatus").text("WebSocket supported by your Browser!");
			  $("#appstatus").css('color', '#555555');

	       // Let us open a web socket
				 var ws_url = websocket_domain + "/realtime" + "?identifier="+myDevice;
				 console.log("ws url:"+ws_url);
	       var ws = new WebSocket(websocket_domain +  "/realtime");

	       ws.onopen = function()
	       {
	          // Web Socket is connected
						console.log('WebSocket opened');
	          $("#appstatus").text("WebSocket opened");
						//ws.send({"identifier"=myDevice);
	       };

	       ws.onmessage = function (evt)
	       {
					 //console.log(event);
					 try {
							var received_msg = JSON.parse(evt.data);
							console.log('WebSocket Msg: ' + received_msg);
	            //$("#appconsole").text('Data:' + String(received_msg));
							var json_obj = JSON.parse(received_msg);
							console.log(json_obj.type);
							if(json_obj.type)
							{
								switch(json_obj.type) {
								    case "data":
								      //console.log(json_obj.value)
											if(json_obj.resource == "status")
											{
												$("#statusbox").text(''+json_obj['value']);
												if(last_status != json_obj['value'])
												{
													last_status = json_obj['value'];
													if(json_obj['value'] == "Off")
													{
														console.log('device now off');
														$('#myonoffswitch').attr('checked', false);
													}
													else
													{
														console.log('device now on');
														$('#myonoffswitch').attr('checked', true);
													}
												}
											}
											else if(json_obj.resource == "temperature")
											{
												$("#currenttempbox").text(''+json_obj['value']);
											}
											else if(json_obj.resource == "tempset")
											{
												$("#settempbox").text(''+json_obj['value']);
											}

								      break;
								    case "info":
								      console.log(json_obj.message)
								      break;
								  }
							}
						} catch(err) {
							$("#appconsole").text(err.message);
							console.log('WebSocket Error: '+err.message);
						};
	       };

	       ws.onclose = function()
	       {
	          // websocket is closed.
						console.log('WebSocket Closed');
						$("#appstatus").text("WebSocket Connection Closed...");
						startwebsocket();
	       };
	    }
	    else
	    {
	       // The browser doesn't support WebSocket
				 $("#appstatus").text("WebSocket NOT supported by your Browser!");
					 $("#appstatus").css('color', red_color);
	    }
		}

    function fetchData() {
				console.log('fetching data from Murano');
        $("#appconsole").text('Fetching Data For '+myDevice+' From Server...');
				$("#appconsole").css('color', '#555555');

        function onDataReceived(newdata) {
          $("#appstatus").text('Running');
          $("#appstatus").css('color', '555555');
          $("#appconsole").text('Processing Data');
					$("#appconsole").css('color', '#555555');
          var data_to_plot = [];
					// Load all the data in one pass; if we only got partial
					// data we could merge it with what we already have.
          //console.log(series)
					console.log(newdata);
					try {
						if ('keyvalue' in newdata)
						{
							console.log(newdata)

							if(jQuery.isEmptyObject(newdata.keyvalue)) {
								console.log('empty data, device may not exist');
							}
							else if(newdata.keyvalue.error )
							{
								console.log('keyvalue error');
							} else {
								console.log('new keyvalue data');
								//var current_value = eval(newdata.keyvalue);
								//console.log(current_value);
								//json_value = JSON.parse(current_value['value']);
								//console.log(json_value);
								//console.log("time:"+ncurrent_value.timestamp);
								if ('temperature' in newdata.keyvalue.state.device) $("#currenttempbox").text(''+newdata.keyvalue.state.device['temperature']);
								if ('status' in newdata.keyvalue.state.device) {
									$("#statusbox").text(''+newdata.keyvalue.state.device['status']);
									if(last_status != newdata.keyvalue.state.device['status'])
									{
										last_status = newdata.keyvalue.state.device['status'];
										if(newdata.keyvalue.state.device['status'] == "Off")
										{
											console.log('device now off');
											$('#myonoffswitch').attr('checked', false);
										}
										else
										{
											console.log('device now on');
											$('#myonoffswitch').attr('checked', true);
										}
									}
								}
								if ('tempset' in newdata.keyvalue.state.device) $("#settempbox").text(''+newdata.keyvalue.state.device['tempset']);
								getkv = 0;  //only get at first to make sure we have initial data
							}

						}

						if ('timeseries' in newdata) {
							if(jQuery.isEmptyObject(newdata.timeseries)) {
								console.log('empty data, device may not exist');
							}
							else if (newdata.timeseries.status == 'Bad request')
							{
								//Database error
								console.log(newdata.status)
								$("#appconsole").text(newdata.status);
								$("#appconsole").css('color', red_color);
								$("#graphmessage").text('Data Not Available for: '+myDevice);
							}
							else if (newdata.timeseries.error)
							{
								//Database error
								console.log(newdata.timeseries.error)
								$("#appconsole").text(newdata.timeseries.error);
								$("#appconsole").css('color', red_color);
								$("#graphmessage").text('Data Not Available for: '+myDevice);
							}
							else if (newdata.timeseries.results[0].error)
							{
								//Database error
								console.log('recevied database error response')
								$("#appconsole").text('Server Time Series Database Error');
								$("#appconsole").css('color', red_color);
								$("#graphmessage").text('Data Not Available for: '+myDevice);
							}
							else if (jQuery.isEmptyObject(newdata.timeseries.results[0]))
							{
								//Database error
								console.log('no valid timeseries data in db, check device')
								$("#appconsole").text('No data for this device');
								$("#graphmessage").text('Data Not Available for: '+myDevice);
							}
							else
							{
								console.log('valid data return for: '+myDevice);
								ts_counter=0;
			          for (j = 0; j < newdata.timeseries.results[0].series.length; j++)
			          {
								  var data = newdata.timeseries.results[0].series[j].values;
			            var friendly = newdata.timeseries.results[0].series[j].name;
			            var units = "";
									var lines = {};
									var bars = {};
									var last_val = newdata.timeseries.results[0].series[j].values[data.length-1][1];

			            if (friendly == "temperature")
			            {
			              units = "F";
										friendly = "Temperature";
										lines = { lineWidth: 1.5, fill: 0.3};
			            }
			            else if (friendly == "tempset")
			            {
			              units = "F";
										friendly = "Temp Setting";
										lines = { lineWidth: 0.5, fill: false, steps: true, show:true};
										bars = {};
										//bars = { barWidth:1, align:"center",show:true, fill:0.1 };
			            }
			            data_to_plot.push({
			                  label: friendly + ' - '+ last_val + ' ' +units,
			                  data: data,
			                  units: units,
												lines: lines,
												bars: bars
			              });
			          }
								$("#graphmessage").text('');
								$.plot("#graph", data_to_plot, graph_options);
								$("#appconsole").text('Data Plotted');
								$("#appconsole").css('color', '#555555');
						  }
						}
						else {
							ts_counter--;
							console.log('no ts data:'+ts_counter);
						}
					}
					catch (e) {
					   // statements to handle any exceptions
					   console.error('exception:' + tostring(e)); // pass exception object to error handler
					}
					if (updateInterval != 0)
						{setTimeout(fetchData, updateInterval*1000);}
				}

        function onError( jqXHR, textStatus, errorThrown) {
          console.log('error: ' + textStatus + ',' + errorThrown);
          $("#appconsole").text('No Server Response');
          $("#appstatus").text('Server Offline');
          $("#appstatus").css('color', red_color);
					if (updateInterval != 0)
						{setTimeout(fetchData, updateInterval+3000);}
        }

				var getts="0";
				if(ts_counter <= 0){
					getts="1";
				}
				$.ajax({
					url: app_domain+"device/data?identifier="+myDevice+"&window="+timeWindow+"&getts="+getts+"&getkv="+getkv,
					async: true,
					type: "GET",
					dataType: "json",
					success: onDataReceived,
          crossDomain: true,
          error: onError,
          statusCode: {
            504: function() {
              console.log( "server not responding" );
              $("#appstatus").text('Server Not Responding 504');
              $("#appstatus").css('color', red_color);
            }
          }
          ,timeout: 10000
        });

			}


		$("#updateInterval").val(updateInterval).change(function () {
			var v = $(this).val();
			if (v && !isNaN(+v)) {
				if(updateInterval == 0)
					{setTimeout(fetchData, 1000);} //updates were turned off, start again
				updateInterval = +v;
				if (updateInterval > 20000) {
					updateInterval = 20000;
				}
				$(this).val("" + updateInterval);

			}
		});

		$("#timeWindow").val(timeWindow).change(function () {
			var v = $(this).val();
			if (v && !isNaN(+v)) {
				timeWindow = +v;
				if (timeWindow < 1) {
					timeWindow = 1;
				} else if (timeWindow > 360) {
					timeWindow = 360;
				}
				$(this).val("" + timeWindow);
			}
		});


		$("#myonoffswitch").click(function() {
		    // access properties using this keyword
				console.log($(this).val());
				var control;
				if($(this).is(":checked"))
				{
		        // if checked ...
		        control = 1;
		    } else {
		        control = 0;
		    }

				$.ajax({
					url: app_domain+"device",
					type: "post",
					//dataType: "json",
					//success: onDataReceived,
					contentType: "application/json",
					data: JSON.stringify({ "identifier": myDevice, "control": control }),
					crossDomain: true,
					//error: onError,
					statusCode: {
						504: function() {
							console.log( "server not responding" );
							$("#appstatus").text('Server Not Responding 504');
							$("#appstatus").css('color', red_color);
						}
					}
					,timeout: 4000
				});

		});

		$("#tempsetbutton").click(function(){

			console.log('sending requested temp setting:'+tempset);
			$("#requestnote").text("requesting...");

			$.ajax({
				url: app_domain+"device",
				type: "post",
				//dataType: "json",
				success: function() {
					$("#tempset").val(""); //clear form field
					$("#requestnote").text("");
				},
				contentType: "application/json",
				data: JSON.stringify({ "identifier": myDevice, "tempset": tempset }),
				crossDomain: true,
				//error: onError,
				statusCode: {
					504: function() {
						console.log( "server not responding" );
						$("#appstatus").text('Server Not Responding 504');
						$("#appstatus").css('color', red_color);
						$("#requestnote").text("server error");
					}
				}
				,timeout: 4000
			});

    });

		$("#tempset").val(tempset).change(function () {
			var v = $(this).val();
			if (v && !isNaN(+v)) {
				var tmp_tempset = +v;
				if (tmp_tempset < 30) {
					tmp_tempset = 30;
				} else if (tmp_tempset > 120) {
					tmp_tempset = 120;
				}
				$(this).val("" + tmp_tempset);
				tempset = tmp_tempset;
			}
		});

		$("#specificdevice").val(myDevice).change(function () {
			var v = $(this).val();
			if (v) {
				myDevice = v;
				console.log('new device identity:' + myDevice);
				$(this).val("" + myDevice);
				$("#currentdevice").text(myDevice);
				$("#graphmessage").text('Graph: Retrieving New Device Data Now for '+myDevice);
				$("#graph").empty();
			}
		});

		fetchData();
		startwebsocket();


		$("#footer").prepend("Exosite Murano Example");
	});
