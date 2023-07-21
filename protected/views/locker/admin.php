<script type="text/javascript">
	function processAction(type, id) {
		switch (type) {
			case 'update':
				window.location = '<?php echo $this->createUrl('update'); ?>/' + id;
				break;
			case 'delete':
				if (confirm('Do you really want to delete location with id ' + id)) {
					$.post('<?php echo $this->createUrl('delete'); ?>/' + id  + '?ajax=1', {
					}, function() {window.location.reload();});
				}
				break;
			case 'approve':
				$.post('<?php echo $this->createUrl('approve'); ?>/' + id  + '?ajax=1', {
				}, function() {window.location.reload();});
				break;
			case 'decline':
				$.post('<?php echo $this->createUrl('decline'); ?>/' + id  + '?ajax=1', {
				}, function() {window.location.reload();});	
				break;
		}
	}
</script>
<?php
$this->breadcrumbs=array(
	'Lockers'
);
$pageSize=Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']);
?>

<h1>Manage Lockers</h1>

<p>
You may optionally enter a comparison operator (<b>&lt;</b>, <b>&lt;=</b>, <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;&gt;</b>
or <b>=</b>) at the beginning of each of your search values to specify how the comparison should be done.
</p>
<div class="right">
	<?php echo CHtml::htmlButton('Export to CSV', array('id' => 'export-button', 'class' => 'span-3 button')); ?>
</div>
<br/>
<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'locker-grid',
	'dataProvider'=>$model->search(),
	'filter'=>$model,
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'summaryText' => 'Displaying {start}-{end} of {count} result(s). Show items per page: ' . CHtml::dropDownList('pageSize', $pageSize, array(10 => 10, 20 => 20, 50 => 50, 100 => 100), array(
		'onchange' => "$.fn.yiiGridView.update('locker-grid',{ data:{pageSize: $(this).val() }})",
	)),
	'columns'=>array(
		'locker_id',
		array(
			'name' => 'client_search',
			'value' => '$data->client ? $data->client->getModelDisplay() : ""'
		),
		array(
			'name' => 'training_id',
			'value' => '$data->training ? $data->training->getModelDisplay() : ""'
		),
		array(
			'name' => 'type',
			'value'=>'$data->getType()',
			'filter'=>CHtml::listData(
				array(
					array('id'=>'m', 'title'=>'Male'),
					array('id'=>'f', 'title'=>'Female'),
				), 'id', 'title'),
		),
		array(
			'name' => 'status',
			'filter'=>CHtml::listData(
				array(
					array('id'=>'closed', 'title'=>'closed'),
					array('id'=>'open', 'title'=>'open'),
					array('id'=>'free', 'title'=>'free'),
				), 'id', 'title'),
		),
		array(
			'name' => 'key_status',
			'value'=>'$data->key_request ? "New key request" : ($data->key ? "Key approved" : "No key")',
			'filter'=>CHtml::listData(
				array(
					array('id'=>'no_key', 'title'=>'No key'),
					array('id'=>'key_request', 'title'=>'New key request'),
					array('id'=>'key', 'title'=>'Key approved'),
				), 'id', 'title'),
		),
		array(
			'header'=>'Action',
			'type'=>'raw',
			'value'=>array($this,'gridActionColumn')
		)
	),
)); ?>

<?php echo CHtml::htmlButton('New Locker', array(
	'submit' => $this->createUrl('locker/create', array('back' => 'admin'))
)) ?>
<?php echo CHtml::htmlButton('Open Men\'s lockes', array(
	'submit' => $this->createUrl('locker/openMan', array('back' => 'admin'))
)) ?>
<?php echo CHtml::htmlButton('Open Women\'s lockes', array(
	'submit' => $this->createUrl('locker/openWoman', array('back' => 'admin'))
)) ?>
<?php echo CHtml::htmlButton('Log', array(
	'submit' => $this->createUrl('locker/log')
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
			$.fn.yiiGridView.update('locker-grid',{ 
				success: function() {
					$('#locker-grid').removeClass('grid-view-loading');
					window.location = '<?php echo $this->createUrl('locker/exportFile') ?>';
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