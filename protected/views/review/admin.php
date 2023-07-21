<script type="text/javascript">
	function processAction(type, id) {
		switch (type) {
			case 'update':
				window.location = '<?php echo $this->createUrl('review/update'); ?>/' + id;
				break;
			case 'delete':
				if (confirm('Do you really want to delete review with id ' + id)) {
					$.post('<?php echo $this->createUrl('review/delete'); ?>/' + id  + '?ajax=1', {
					}, function() {window.location.reload();});
				}
				break;
			case 'generateChart':	
				window.location = '<?php echo $this->createUrl('review/generateChart'); ?>/' + id;
				break;
			case 'chart':
				window.location = '<?php echo $this->createUrl('/'); ?>/media/chart/review/' + id + '.png';
				break;
		}
	}
</script>
<?php
$this->breadcrumbs=array(
	'Reviews'
);
$pageSize=Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']);
?>

<h1>Manage Reviews</h1>

<p>
You may optionally enter a comparison operator (<b>&lt;</b>, <b>&lt;=</b>, <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;&gt;</b>
or <b>=</b>) at the beginning of each of your search values to specify how the comparison should be done.
</p>
<div class="right">
	<?php echo CHtml::htmlButton('Export to CSV', array('id' => 'export-button', 'class' => 'span-3 button')); ?>
</div>
<br/>
<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'review-grid',
	'dataProvider'=>$model->search(),
	'filter'=>$model,
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'summaryText' => 'Displaying {start}-{end} of {count} result(s). Show items per page: ' . CHtml::dropDownList('pageSize', $pageSize, array(10 => 10, 20 => 20, 50 => 50, 100 => 100), array(
		'onchange' => "$.fn.yiiGridView.update('review-grid',{ data:{pageSize: $(this).val() }})",
	)),
	'columns'=>array(
		'id',
		'file',
		'duration',
		'kcal',
		'heart_rate',
		array(
			'name' => 'training_type',
			'filter' => Review::getTrainingTypes(),
			'value' => '$data->getTrainingType()'
		),
		array(
			'name' => 'type',
			'filter' => Review::getTypes(),
			'value' => '$data->getType()'
		),
		array(
			'name' => 'goal',
			'value' => '$data->goal . " " . $data->goal_metric'
		),
		array(
			'name' => 'bonus_goal',
			'value' => '$data->bonus_goal . " " .$data->bonus_goal_metric'
		),
		'result',
		array(
			'name' => 'exerciseset_search',
			'value'=>'$data->exerciseset->name ',
		),
		array(
			'name' => 'training_search',
			'value'=>'($data->training ? $data->training->date  . " " . $data->training->starttime  . " " . $data->training->getEndTime(): "")',
		),
		'distance',
		'speed',
		array(
			'header'=>'Action',
			'type'=>'raw',
			'value'=>array($this,'gridActionColumn')
		)
	),
)); ?>

<?php echo CHtml::htmlButton('New Review', array(
	'submit' => $this->createUrl('review/create', array('back' => 'admin'))
)) ?>
<script type="text/javascript">
	$(document).ready(function() {
		$('#export-button').on('click',function() {
			$.fn.yiiGridView.doExport();
		});
		
		function getData() {
			var data = $('.filters input, .filters select').serialize() + '&export=true';
			<?php if (isset($_GET[$model->search()->getPagination()->pageVar])): ?>
				data += '&<?php echo $model->search()->getPagination()->pageVar	?>=<?php echo $_GET[$model->search()->getPagination()->pageVar] ?>';
			<?php endif;?>
			return data;
		}
		
		$.fn.yiiGridView.doExport = function() {
			$.fn.yiiGridView.update('review-grid',{ 
				success: function() {
					$('#review-grid').removeClass('grid-view-loading');
					window.location = '<?php echo $this->createUrl('review/exportFile') ?>';
				},
				data: getData()
			});
		}
		$('.grid-view .items tbody tr').live('dblclick', function(){
			var id_class;
			$($(this).attr('class').split(' ')).each(function() { 
				if (this.indexOf('id_') === 0) {
					id_class = this;
				}    
			});
			processAction('update', id_class.replace('id_',''));
		});
	});
</script>