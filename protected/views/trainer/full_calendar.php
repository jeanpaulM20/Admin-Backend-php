<?php
$this->breadcrumbs=array(
	'Trainers'=>array('admin'),
	'Avalibility calendar',
);
?>
<?php
    foreach(Yii::app()->user->getFlashes() as $key => $message) {
        echo '<div class="flash-' . $key . '">' . $message . "</div>\n";
    }
?>
<h1>Avaliability calendar</h1>
<?php echo CHtml::dropDownList('trainer_id', '',Trainer::getDropdownList(true), array('multiple'=>true, 'class' => 'chzn-select', 'style' => 'width:500px')) ?>
<br/><br/>
<div id="calendar"></div>
<?php
	$this->beginWidget('zii.widgets.jui.CJuiDialog', array(
		'id'=>'avalability',
		'options'=>array(
			'title'=>'Avaliability',
			'autoOpen'=>false,
		),
));
?>
<div id="updateForm"></div>
<?php $this->endWidget('zii.widgets.jui.CJuiDialog'); ?>
<script type="text/javascript">
	$(document).ready(function() {
		var copying = false;
		$('#calendar').fullCalendar({
			firstDay: 1,
			allDaySlot: false,
			slotMinutes: 15,
			axisFormat: 'H:mm',
			firstHour: 8,
			defaultView: '<?php echo $view ?>',
			date: <?php echo (int)date('d', strtotime($date)) ?>,
			month: <?php echo (int)date('m', strtotime($date)) - 1 ?>,
			year: <?php echo (int)date('Y', strtotime($date)) ?>,
			columnFormat: {
				month: 'ddd',
				week: 'ddd dd.MM',
				day: 'dddd dd.MM'
			},
			timeFormat: {
				agenda: 'H:mm{ - H:mm}',
				'': 'H:mm{ - H:mm}'
			},

			buttonText: {
				prev:     '&nbsp;&#9668;&nbsp;',
				next:     '&nbsp;&#9658;&nbsp;',
				prevYear: '&nbsp;&lt;&lt;&nbsp;',
				nextYear: '&nbsp;&gt;&gt;&nbsp;',
				today:    'Today',
				month:    'Month',
				week:	  'Week',
				day:      'Day'
			},

			header: {
				left:   'prevYear,prev',
				center: 'title',
				right:  'today month,agendaWeek,agendaDay next,nextYear'
			},

			editable: true,
			disableResizing: true,

			events: function(start, end, callback) {
				$.ajax({
					url: '<?php echo $this->createUrl('trainer/listAvailability') ?>',
					dataType: 'json',
					data: {
						start: Math.round(start.getTime() / 1000),
						end: Math.round(end.getTime() / 1000),
						trainer_id: $('#trainer_id').val()
					},
					success: function(doc) {
						callback(doc);
					}
				});
			},
			dayClick: function(date, allDay, jsEvent, view) {
				if (view.name == 'month') {
					$('#calendar')
						.fullCalendar( 'gotoDate', date)
						.fullCalendar( 'changeView', 'agendaDay');

				} else {
					$('#updateForm').load('<?php echo $this->createUrl('form') ?>/?view=' + $('#calendar').fullCalendar('getView').name, function() {
						$('#avalability').dialog('open');
						jQuery('#TrainerAvailability_date')
							.datepicker({'showAnim':'fold','dateFormat':'dd-mm-yy' })
							.datepicker('setDate', date);
						jQuery('#TrainerAvailability_from')
							.timepicker({'timeFormat':'hh:mm', 'stepMinute': 15})
							.timepicker('setDate', date);
						jQuery('#TrainerAvailability_to')
							.timepicker({'timeFormat':'hh:mm', 'stepMinute': 15})
							.timepicker('setDate', date);	
					});
				}
			},
			eventClick: function(calEvent, jsEvent, view) {
				$('#updateForm').load('<?php echo $this->createUrl('form') ?>/' + calEvent.id + '?view=' + $('#calendar').fullCalendar('getView').name, function() {
					$('#avalability').dialog('open');
						jQuery('#TrainerAvailability_date')
							.datepicker({'showAnim':'fold','dateFormat':'dd-mm-yy'});
						jQuery('#TrainerAvailability_from')
							.timepicker({'timeFormat':'hh:mm', 'stepMinute': 15});
						jQuery('#TrainerAvailability_to')
							.timepicker({'timeFormat':'hh:mm', 'stepMinute': 15});
				});
			},
			eventDragStart: function(event, jsEvent) {
				copying = jsEvent.shiftKey;
			},
					
			eventDrop: function(event,dayDelta,minuteDelta,allDay, revertFunc, jsEvent, ui) {
				if (copying) {
					$.ajax({
						url: '<?php echo $this->createUrl('trainer/copyAvaliability') ?>/' + event.id,
						dataType: 'json',
						data: {
							dayDelta: dayDelta,
							minuteDelta: minuteDelta
						},
						success: function(doc) {
							if (doc.error) {
								alert(doc.error);
								revertFunc();
							} else {
								if (doc.data) {
									var eventCopy = {};
									eventCopy.details = doc.data;
									eventCopy.title = event.title;
									if (event._start) {
										eventCopy._start = new Date(event._start.valueOf());
										eventCopy.start = new Date(event._start.valueOf());
									}
									if (event._end) {
										eventCopy._end = new Date(event._end.valueOf());
										eventCopy.end = new Date(event._end.valueOf());
									}
									eventCopy.allDay = false;
									eventCopy.id = doc.id;
									eventCopy._id = doc.id;
									console.log(eventCopy);
									revertFunc();
									$("#calendar").fullCalendar('renderEvent', eventCopy)
								}
							}
						}
					});
				} else {
					$.ajax({
						url: '<?php echo $this->createUrl('trainer/moveAvaliability') ?>/' + event.id,
						dataType: 'json',
						data: {
							dayDelta: dayDelta,
							minuteDelta: minuteDelta
						},
						success: function(doc) {
							if (doc.error) {
								alert(doc.error);
								revertFunc();
							} else {
								if (doc.data) {
									event.details = doc.data;
									$('#calendar').fullCalendar('updateEvent', event);
								}
							}
						}
					});
				}
			},
			
			eventRender: function(event, element) {
				var content = $(element).find('.fc-event-content');
				if(content.length) {
					content.html(event.details);
				}
			}
		});
		$('#trainer_id').bind('change', function(){
			$('#calendar').fullCalendar('refetchEvents');
		});
	});
</script>
<?php $this->widget( 'ext.EChosen.EChosen' ); ?>