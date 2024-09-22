
<form id="new_url_form" action="javascript:add_link();" method="get">
	<label>Link:</label>
	<input type="text" id="add-url" name="url" value="" class="text" placeholder="https://">
	<label class="short">Short URL:</label>
	<input type="text" id="add-keyword" name="keyword" value="" class="text" placeholder="Optional">
	<input type="hidden" id="nonce-add" name="nonce-add" value="">
	<input type="button" id="add-button" name="add-button" value="Shorten" onclick="add_link();">
</form>

