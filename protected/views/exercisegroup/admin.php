<script type="text/javascript">
	function processAction(type, id) {
		switch (type) {
			case 'update':
				window.location = '<?php echo $this->createUrl('exercisegroup/update'); ?>/' + id;
				break;
			case 'delete':
				if (confirm('Do you really want to delete subgroup with id ' + id)) {
					$.post('<?php echo $this->createUrl('exercisegroup/delete'); ?>/' + id  + '?ajax=1', {
					}, function() {window.location.reload();});
				}
				break;
			}
		}
</script>
<?php
$this->breadcrumbs = array(
	'Exercises'
);
$pageSize = Yii::app()->user->getState('pageSize', Yii::app()->params['defaultPageSize']);
?>

<h1>Manage Exercise subgroups</h1>

<p>
	You may optionally enter a comparison operator (<b>&lt;</b>, <b>&lt;=</b>, <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;&gt;</b>
	or <b>=</b>) at the beginning of each of your search values to specify how the comparison should be done.
</p>
<div class="right">
	<?php echo CHtml::htmlButton('Export to CSV', array('id'	 => 'export-button', 'class'	 => 'span-3 button')); ?>
</div>
<br/>
<?php
$this->widget('zii.widgets.grid.CGridView', array(
	'id'					 => 'exercisesubgroup-grid',
	'dataProvider'			 => $model->search(),
	'filter'				 => $model,
	'rowCssClassExpression'	 => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'summaryText'			 => 'Displaying {start}-{end} of {count} result(s). Show items per page: ' . CHtml::dropDownList('pageSize', $pageSize, array(10	 => 10, 20	 => 20, 50	 => 50, 100	 => 100), array(
		'onchange'	 => "$.fn.yiiGridView.update('exercisesubgroup-grid',{ data:{pageSize: $(this).val() }})",
	)),
	'columns'	 => array(
		'id',
		'name',
		array(
			'header' => 'Action',
			'type'	 => 'raw',
			'value'	 => array($this, 'gridActionColumn')
		)
	),
));
?>

<?php
echo CHtml::htmlButton('New Exercise subgroup', array(
	'submit' => $this->createUrl('exercisegroup/create', array('back' => 'admin'))
))
?>

<script type="text/javascript">
		$(document).ready(function() {
			$('#export-button').on('click',function() {
				$.fn.yiiGridView.doExport();
			});
		
			function getData() {
				var data = $('.filters input, .filters select').serialize() + '&export=true';
<?php if (isset($_GET[$model->search()->getPagination()->pageVar])): ?>
					data += '&<?php echo $model->search()->getPagination()->pageVar ?>=<?php echo $_GET[$model->search()->getPagination()->pageVar] ?>';
<?php endif; ?>
				return data;
			}
		
			$.fn.yiiGridView.doExport = function() {
				$.fn.yiiGridView.update('exercisegroup-grid',{ 
					success: function() {
						$('#exercisegroup-grid').removeClass('grid-view-loading');
						window.location = '<?php echo $this->createUrl('exercisegroup/exportFile') ?>';
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