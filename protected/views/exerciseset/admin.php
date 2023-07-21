<script type="text/javascript">
	function processAction(type, id) {
		switch (type) {
			case 'update':
				window.location = '<?php echo $this->createUrl('exerciseset/update'); ?>/' + id;
				break;
			case 'delete':
				if (confirm('Do you really want to delete trainer with id ' + id)) {
					$.post('<?php echo $this->createUrl('exerciseset/delete'); ?>/' + id, {
					}, function() {window.location.reload();});
				}
				break;
		}
	}
</script>
<?php
$this->breadcrumbs=array(
	'ExerciseSets'
);
$pageSize=Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']);
?>

<h1>Manage ExerciseSets</h1>

<p>
You may optionally enter a comparison operator (<b>&lt;</b>, <b>&lt;=</b>, <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;&gt;</b>
or <b>=</b>) at the beginning of each of your search values to specify how the comparison should be done.
</p>
<div class="right">
	<?php echo CHtml::htmlButton('Export to CSV', array('id' => 'export-button', 'class' => 'span-3 button')); ?>
</div>
<br/>
<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'exerciseset-grid',
	'dataProvider'=>$model->search(),
	'filter'=>$model,
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'summaryText' => 'Displaying {start}-{end} of {count} result(s). Show items per page: ' . CHtml::dropDownList('pageSize', $pageSize, array(10 => 10, 20 => 20, 50 => 50, 100 => 100), array(
		'onchange' => "$.fn.yiiGridView.update('exerciseset-grid',{ data:{pageSize: $(this).val() }})",
	)),
	'columns'=>array(
		'id',
		'name',
			array(
	'name' => 'archive',
	'value'=>array($this,'gridArchiveColumn'),
	'filter'=>CHtml::listData(
		array(
			array('id'=>'1', 'title'=>'Archive'),
			array('id'=>'0', 'title'=>'Not Archive'),
		), 'id', 'title'),
),
		array(
	'name' => 'published',
	'value'=>array($this,'gridPublishedColumn'),
	'filter'=>CHtml::listData(
		array(
			array('id'=>'1', 'title'=>'Published'),
			array('id'=>'0', 'title'=>'Not Published'),
		), 'id', 'title'),
),
		array(
			'header'=>'Action',
			'type'=>'raw',
			'value'=>array($this,'gridActionColumn')
		)
	),
)); ?>

<?php echo CHtml::htmlButton('New ExerciseSet', array(
	'submit' => $this->createUrl('exerciseset/create', array('back' => 'admin'))
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
			$.fn.yiiGridView.update('exerciseset-grid',{ 
				success: function() {
					$('#exerciseset-grid').removeClass('grid-view-loading');
					window.location = '<?php echo $this->createUrl('exerciseset/exportFile') ?>';
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