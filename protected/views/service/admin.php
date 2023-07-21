<script type="text/javascript">
	function processAction(type, id) {
		switch (type) {
			case 'update':
				window.location = '<?php echo $this->createUrl('service/update'); ?>/' + id;
				break;
			case 'delete':
				if (confirm('Do you really want to delete service with id ' + id)) {
					$.post('<?php echo $this->createUrl('service/delete'); ?>/' + id  + '?ajax=1', {
					}, function() {window.location.reload();});
				}
				break;
		}
	}
</script>
<?php
$this->breadcrumbs=array(
	'Services'=>array('admin'),
	'Manage',
);


?>

<h1>Manage Services</h1>

<p>
You may optionally enter a comparison operator (<b>&lt;</b>, <b>&lt;=</b>, <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;&gt;</b>
or <b>=</b>) at the beginning of each of your search values to specify how the comparison should be done.
</p>

<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'service-grid',
	'dataProvider'=>$model->search(),
	'filter'=>$model,
	'rowCssClassExpression'	 => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'columns'=>array(
		'id',
		'model',
		'service_alias',
		'title',
		'description',
		'service_params',
		'select_fields',
		'condition',
		'order',
		'group',
		array(
			'name' => 'publish',
			'filter' => CHtml::listData(array(
				array ('id' => 0, 'title' => 'Not published'),
				array ('id' => 1, 'title' => 'Published'),
			), 'id', 'title'),
			'value'=>array($this,'gridPublishColumn')
		),
		'sortOrder',
		array(
			'header'=>'Action',
			'type'=>'raw',
			'value'=>array($this,'gridActionColumn')
		),
	),
)); ?>

<?php echo CHtml::htmlButton('New Service', array(
	'submit' => $this->createUrl('service/create', array('back' => 'admin'))
)) ?>
<script type="text/javascript">
	$(document).ready(function() {
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