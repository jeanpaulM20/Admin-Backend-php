<script type="text/javascript">
	function processAction(type, id) {
		switch (type) {
			case 'update':
				window.location = '<?php echo $this->createUrl('trainingplan/update'); ?>/' + id;
				break;
			case 'delete':
				if (confirm('Do you really want to delete trainingplan with id ' + id)) {
					$.post('<?php echo $this->createUrl('trainingplan/delete'); ?>/' + id  + '?ajax=1', {
					}, function() {window.location.reload();});
				}
				break;
			case 'pdf':
				window.location = '<?php echo $this->createUrl('trainingplan/pdf'); ?>/' + id;
				break;	
		}
	}
</script>
<?php
$this->breadcrumbs=array(
	'Trainingplans'
);
$pageSize=Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']);
?>

<h1>Manage Trainingplans</h1>

<p>
You may optionally enter a comparison operator (<b>&lt;</b>, <b>&lt;=</b>, <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;&gt;</b>
or <b>=</b>) at the beginning of each of your search values to specify how the comparison should be done.
</p>
<div class="right">
	<?php echo CHtml::htmlButton('Export to CSV', array('id' => 'export-button', 'class' => 'span-3 button')); ?>
</div>
<br/>
<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'trainingplan-grid',
	'dataProvider'=>$model->search(),
	'filter'=>$model,
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'summaryText' => 'Displaying {start}-{end} of {count} result(s). Show items per page: ' . CHtml::dropDownList('pageSize', $pageSize, array(10 => 10, 20 => 20, 50 => 50, 100 => 100), array(
		'onchange' => "$.fn.yiiGridView.update('trainingplan-grid',{ data:{pageSize: $(this).val() }})",
	)),
	'columns'=>array(
		'id',
		array(
			'name' => 'client_search',
			'value'=>'$data->client->clientid  . " " . $data->client->surname  . " " . $data->client->name ',
		),
		array(
			'name' => 'type',
			'value' => '$data->getType()',
			'filter'=> TrainingPlan::getTypeValues(),
		),
		'new_pro',
		'load_duration', 
		'repeat',
		'temp',
		'rates',
		'phase',
		'personal_week',
		'own_week',
		'goal',
		array(
			'header'=>'Action',
			'type'=>'raw',
			'value'=>array($this,'gridActionColumn')
		)
	),
)); ?>

<?php echo CHtml::htmlButton('New Trainingplan', array(
	'submit' => $this->createUrl('trainingplan/create', array('back' => 'admin'))
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
			$.fn.yiiGridView.update('trainingplan-grid',{ 
				success: function() {
					$('#trainingplan-grid').removeClass('grid-view-loading');
					window.location = '<?php echo $this->createUrl('trainingplan/exportFile') ?>';
				},
				data: getData()
			});
		}
		$('#trainingplan-grid .items tbody tr').live('dblclick', function(){
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