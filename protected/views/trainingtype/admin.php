<script type="text/javascript">
	function processAction(type, id) {
		switch (type) {
			case 'update':
				window.location = '<?php echo $this->createUrl('trainingtype/update'); ?>/' + id;
				break;
			case 'delete':
				if (confirm('Do you really want to delete training type with id ' + id)) {
					$.post('<?php echo $this->createUrl('trainingtype/delete'); ?>/' + id  + '?ajax=1', {
					}, function() {window.location.reload();});
				}
				break;
		}
	}
</script>
<?php
$this->breadcrumbs=array(
	'Training Types'
);
$pageSize=Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']);
?>

<h1>Manage Training Types</h1>

<p>
You may optionally enter a comparison operator (<b>&lt;</b>, <b>&lt;=</b>, <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;&gt;</b>
or <b>=</b>) at the beginning of each of your search values to specify how the comparison should be done.
</p>
<div class="right">
	<?php echo CHtml::htmlButton('Export to CSV', array('id' => 'export-button', 'class' => 'span-3 button')); ?>
</div>
<br/>
<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'trainingtype-grid',
	'dataProvider'=>$model->search(),
	'filter'=>$model,
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'summaryText' => 'Displaying {start}-{end} of {count} result(s). Show items per page: ' . CHtml::dropDownList('pageSize', $pageSize, array(10 => 10, 20 => 20, 50 => 50, 100 => 100), array(
		'onchange' => "$.fn.yiiGridView.update('goal-grid',{ data:{pageSize: $(this).val() }})",
	)),
	'columns'=>array(
		'id',
		'name_en',
		'name_de',
		'abbr',
		array(
			'name' => 'service',
			'value'=>array($this,'gridServiceColumn'),
			'filter'=>CHtml::listData(
				array(
					array('id'=>'1', 'title'=>'Is a service'),
					array('id'=>'0', 'title'=>'Not a service'),
				), 'id', 'title'),
		),
		'duration',
		'participants',
		'sort',
		array(
			'name' => 'no_avaliability',
			'value'=>array($this,'gridNoAvColumn'),
			'filter'=>CHtml::listData(
				array(
					array('id'=>'1', 'title'=>'No avaliability'),
					array('id'=>'0', 'title'=>'Avaliability needed'),
				), 'id', 'title'),
		),
		
		array(
			'name' => 'no_locker',
			'value'=>array($this,'gridNoLockerColumn'),
			'filter'=>CHtml::listData(
				array(
					array('id'=>'1', 'title'=>'No locker'),
					array('id'=>'0', 'title'=>'Locker needed'),
				), 'id', 'title'),
		),
		array(
			'name' => 'avaliability_from',
			'value' => '$data->avFrom ? $data->avFrom->name_en : "" ',
			'filter' => TrainingType::getDropdownList(),
		),
		array(
			'name' => 'credits_from',
			'value' => '$data->crFrom ? $data->crFrom->name_en : "" ',
			'filter' => TrainingType::getDropdownList(),
		),
		array(
			'header'=>'Action',
			'type'=>'raw',
			'value'=>array($this,'gridActionColumn')
		)
	),
)); ?>

<?php echo CHtml::htmlButton('New Training type', array(
	'submit' => $this->createUrl('trainingtype/create', array('back' => 'admin'))
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
			$.fn.yiiGridView.update('trainingtype-grid',{ 
				success: function() {
					$('#trainingtype-grid').removeClass('grid-view-loading');
					window.location = '<?php echo $this->createUrl('trainingtype/exportFile') ?>';
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