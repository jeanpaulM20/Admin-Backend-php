<script type="text/javascript">
	function processAction(type, id) {
		switch (type) {
			case 'update':
				window.location = '<?php echo $this->createUrl('content/update'); ?>/' + id;
				break;
			case 'delete':
				if (confirm('Do you really want to delete content with id ' + id)) {
					$.post('<?php echo $this->createUrl('content/delete'); ?>/' + id  + '?ajax=1', {
					}, function() {window.location.reload();});
				}
				break;
		}
	}
</script>
<?php
$this->breadcrumbs=array(
	'Contents'
);
$pageSize=Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']);
?>

<h1>Manage Contents</h1>

<p>
You may optionally enter a comparison operator (<b>&lt;</b>, <b>&lt;=</b>, <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;&gt;</b>
or <b>=</b>) at the beginning of each of your search values to specify how the comparison should be done.
</p>
<div class="right">
	<?php echo CHtml::htmlButton('Export to CSV', array('id' => 'export-button', 'class' => 'span-3 button')); ?>
</div>
<br/>
<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'content-grid',
	'dataProvider'=>$model->search(),
	'filter'=>$model,
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'summaryText' => 'Displaying {start}-{end} of {count} result(s). Show items per page: ' . CHtml::dropDownList('pageSize', $pageSize, array(10 => 10, 20 => 20, 50 => 50, 100 => 100), array(
		'onchange' => "$.fn.yiiGridView.update('content-grid',{ data:{pageSize: $(this).val() }})",
	)),
	'columns'=>array(
		'id',
		'name',
		'group',
		array(
	'name' => 'type',
	'value' => array($this, 'gridTypeColumn'),
'filter' => $this->getModel()->getTypeValues(),
),
		'preview',
		'teaser',
		'file',
		array(
	'name' => 'startdate',
	'class'=>'application.extensions.datecolumn.SYDateColumn',
),
		array(
	'name' => 'enddate',
	'class'=>'application.extensions.datecolumn.SYDateColumn',
),
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
	'name' => 'language_search',
	'value'=>'$data->language->language ',
),
		array(
	'name' => 'trainer_search',
	'value'=>'$data->trainer->surname  . " " . $data->trainer->name ',
),
		array(
			'header'=>'Action',
			'type'=>'raw',
			'value'=>array($this,'gridActionColumn')
		)
	),
)); ?>

<?php echo CHtml::htmlButton('New Content', array(
	'submit' => $this->createUrl('content/create', array('back' => 'admin'))
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
			$.fn.yiiGridView.update('content-grid',{ 
				success: function() {
					$('#content-grid').removeClass('grid-view-loading');
					window.location = '<?php echo $this->createUrl('content/exportFile') ?>';
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