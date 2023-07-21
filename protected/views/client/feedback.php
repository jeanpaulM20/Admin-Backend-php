<?php
$this->breadcrumbs=array(
	'Feedback Chat'
);
$pageSize=Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']);
?>

<h1>Manage Feedback Chat messages</h1>

<p>
You may optionally enter a comparison operator (<b>&lt;</b>, <b>&lt;=</b>, <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;&gt;</b>
or <b>=</b>) at the beginning of each of your search values to specify how the comparison should be done.
</p>
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
		array(
			'name' => 'client_search',
			'value' => '$data->client ? $data->client->getModelDisplay() : ""'
		),
		array(
			'name' => 'trainer_search',
			'value' => '$data->trainer ? $data->trainer->getModelDisplay() : ""'
		),
		'text',
		'read_client', 
		'read_trainer'
	),
)); ?>

<?php echo CHtml::htmlButton('New Review', array(
	'submit' => $this->createUrl('review/create', array('back' => 'admin'))
)) ?>

<script type="text/javascript">
</script>