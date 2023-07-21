<script type="text/javascript">
	function processAction(type, id) {
		switch (type) {
			case 'update':
				window.location = '<?php echo $this->createUrl('credits/update'); ?>/' + id;
				break;
			case 'delete':
				if (confirm('Do you really want to delete credits?')) {
					$.post('<?php echo $this->createUrl('credits/delete'); ?>/' + id  + '?ajax=1', {
					}, function() {window.location.reload();});
				}
				break;
		}
	}
</script>
<?php
$this->breadcrumbs=array(
	'Clients' => array('client/admin'),
	'Credits'
);
$pageSize=Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']);
?>

<?php if (Yii::app()->request->getParam('client_id')): ?>
<h1>Manage Credits of <?php echo $model->client->getModelDisplay() ?></h1>
<?php else: ?>
<h1>Manage Credits</h1>
<?php endif; ?>

<p>
You may optionally enter a comparison operator (<b>&lt;</b>, <b>&lt;=</b>, <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;&gt;</b>
or <b>=</b>) at the beginning of each of your search values to specify how the comparison should be done.
</p>
<div class="right">
	<?php echo CHtml::htmlButton('Export to CSV', array('id' => 'export-button', 'class' => 'span-3 button')); ?>
</div>
<br/>
<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'credits-grid',
	'dataProvider'=>$model->search(),
	'filter'=>$model,
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'summaryText' => 'Displaying {start}-{end} of {count} result(s). Show items per page: ' . CHtml::dropDownList('pageSize', $pageSize, array(10 => 10, 20 => 20, 50 => 50, 100 => 100), array(
		'onchange' => "$.fn.yiiGridView.update('credits-grid',{ data:{pageSize: $(this).val() }})",
	)),
	'columns'=>array(
		array(
			'name' => 'client_search',
			'value' => '$data->client ? $data->client->getModelDisplay() : ""',
		),
		array(
			'name' => 'training_type_id',
			'value' => '$data->training_type->name_en',
			'filter' => TrainingType::getDropdownList(),
		),
	 	array(
			'name' => 'abbonement_search',
			'value' => '$data->abbonement->title'
		),
		'price',
		'paid',
	 	'attended',
		array(
			'name' => 'startdate',
			'class'=>'application.extensions.datecolumn.SYDateColumn',
		),
	 	array(
			'name' => 'expires',
			'class'=>'application.extensions.datecolumn.SYDateColumn',
		),
		array(
			'name' => 'sell_date',
			'class'=>'application.extensions.datecolumn.SYDateColumn',
		),
		array(
			'name' => 'soldby_search',
			'value' => '$data->sold_by ? $data->sold_by->getModelDisplay() : ""',
		),
		'professional', 
		'training_target_1', 
		'training_target_2', 
		'acquisition',
		array(
			'name' => 'client_domicile_search',
			'value' => '$data->client->domicile',
		),
		array(
			'header'=>'Action',
			'type'=>'raw',
			'value'=>array($this,'gridActionColumn')
		)
	),
)); ?>

<?php echo CHtml::htmlButton('Allocate', array(
	'submit' => $this->createUrl('credits/allocate', array('client_id' => $model->client_id))
)) ?>

<?php echo CHtml::htmlButton('Allocate Special', array(
	'submit' => $this->createUrl('credits/allocateSpecial', array('client_id' => $model->client_id))
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
			$.fn.yiiGridView.update('credits-grid',{ 
				success: function() {
					$('#credits-grid').removeClass('grid-view-loading');
					window.location = '<?php echo $this->createUrl('credits/exportFile') ?>';
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