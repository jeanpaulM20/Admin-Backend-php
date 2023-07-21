<script type="text/javascript">
	function processAction(type, id) {
		switch (type) {
			case 'view':
				window.location = '<?php echo $this->createUrl('client/view'); ?>/' + id;
				break;
			case 'update':
				window.location = '<?php echo $this->createUrl('client/update'); ?>/' + id;
				break;
			case 'credits':
				window.location = '<?php echo $this->createUrl('credits/admin'); ?>/?client_id=' + id;
				break;	
			case 'anamnese':
				window.location = '<?php echo $this->createUrl('client/anamnese'); ?>/' + id;
				break;	
			case 'anamnesepdf':
				window.location = '<?php echo $this->createUrl('client/anamnesepdf'); ?>/' + id;
				break;		
			case 'qrcode':
				window.location = '<?php echo $this->createUrl('client/qrcode'); ?>/' + id;
				break;	
			case 'delete':
				if (confirm('Do you really want to delete client with id ' + id)) {
					$.post('<?php echo $this->createUrl('client/delete'); ?>/' + id + '?ajax=1', {
					}, function() {window.location.reload();});
				}
				break;
		}
	}
</script>
<?php
$this->breadcrumbs=array(
	'Clients'
);
$pageSize=Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']);
?>

<h1>Manage Clients</h1>

<p>
You may optionally enter a comparison operator (<b>&lt;</b>, <b>&lt;=</b>, <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;&gt;</b>
or <b>=</b>) at the beginning of each of your search values to specify how the comparison should be done.
</p>
<div class="right">
	<?php echo CHtml::htmlButton('Export to CSV', array('id' => 'export-button', 'class' => 'span-3 button')); ?>
</div>
<br/>
<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'client-grid',
	'dataProvider'=>$model->search(),
	'filter'=>$model,
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'summaryText' => 'Displaying {start}-{end} of {count} result(s). Show items per page: ' . CHtml::dropDownList('pageSize', $pageSize, array(10 => 10, 20 => 20, 50 => 50, 100 => 100), array(
		'onchange' => "$.fn.yiiGridView.update('client-grid',{ data:{pageSize: $(this).val() }})",
	)),
	'columns'=>array(
		'id',
		'clientid',
		array(
			'name' => 'gender',
			'value' => '$data->getGender()',
			'filter' => CHtml::listData(
			array(
				array('id'=>'m', 'title'=>'Male'),
				array('id'=>'f', 'title'=>'Female'),
			), 'id', 'title'),
		),
		'surname',
		'name',
		array(
	'name' => 'birthday',
	'class'=>'application.extensions.datecolumn.SYDateColumn',
),
		'e_mail',
		'zip',
		'domicile',
		'phone',
		'mobile',
		'foto',
		'max_heart_rate',
		'min_heart_rate',
		array(
			'name' => 'active',
			'value'=>array($this,'gridActiveColumn'),
			'filter'=>CHtml::listData(
				array(
					array('id'=>'1', 'title'=>'Active'),
					array('id'=>'0', 'title'=>'Not Active'),
				), 'id', 'title'),
		),
		array(
			'name' => 'qrcode_static',
			'value'=>array($this,'gridQrStaticColumn'),
			'filter'=>CHtml::listData(
				array(
					array('id'=>'1', 'title'=>'Yes'),
					array('id'=>'0', 'title'=>'No'),
				), 'id', 'title'),
		),
		array(
			'name' => 'door_access',
			'value'=>array($this,'gridDoorAccessColumn'),
			'filter'=>CHtml::listData(
				array(
					array('id'=>'1', 'title'=>'Yes'),
					array('id'=>'0', 'title'=>'No'),
				), 'id', 'title'),
		),
		
		array(
			'header'=>'Action',
			'type'=>'raw',
			'value'=>array($this,'gridActionColumn')
		)
	),
)); ?>

<?php echo CHtml::htmlButton('New Client', array(
	'submit' => $this->createUrl('client/create', array('back' => 'admin'))
)) ?>

<?php echo CHtml::htmlButton('Manage Abbonements', array(
	'submit' => $this->createUrl('abbonement/admin')
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
			$.fn.yiiGridView.update('client-grid',{ 
				success: function() {
					$('#client-grid').removeClass('grid-view-loading');
					window.location = '<?php echo $this->createUrl('client/exportFile') ?>';
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